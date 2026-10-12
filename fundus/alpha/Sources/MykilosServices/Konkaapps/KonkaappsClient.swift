import Foundation
import MykilosKit

public struct KonkaappsCredentials: Equatable, Sendable {
    public var basicAuth: String
    public init(basicAuth: String) { self.basicAuth = basicAuth }
}

public protocol KonkaappsCredentialsStoring: Sendable {
    func store(_ credentials: KonkaappsCredentials) throws
    func load() throws -> KonkaappsCredentials?
    func clear() throws
}

public struct KeychainKonkaappsCredentialsStore: KonkaappsCredentialsStoring {
    private static let account = "basicAuth"
    private let vault: ServiceCredentialStore

    public init(keychain: KeychainStore = KeychainStore(), userID: String? = CurrentUserContext.current) {
        vault = ServiceCredentialStore(.konkaapps, fields: [CredentialField(Self.account)], keychain: keychain, userID: userID)
    }

    public func store(_ credentials: KonkaappsCredentials) throws {
        try vault.store([Self.account: credentials.basicAuth])
    }

    public func load() throws -> KonkaappsCredentials? {
        guard let values = try vault.load(), let value = values[Self.account] else { return nil }
        return KonkaappsCredentials(basicAuth: value)
    }

    public func clear() throws {
        try vault.clear()
    }
}

public enum KonkaappsError: Error, Equatable, Sendable {
    case notConnected
    case httpError(Int)
    case invalidResponse
}

extension KonkaappsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Kein Kantinen-Zugang hinterlegt — in den Einstellungen eintragen."
        case .httpError(let status):
            switch status {
            case 401, 403:
                return "Die Kantine lehnt den Zugang ab (HTTP \(status)) — Schlüssel prüfen."
            case 404:
                return "Die Kantine kennt diesen Standort nicht (HTTP 404)."
            case 429:
                return "Die Kantine bremst uns aus (HTTP 429) — später erneut versuchen."
            case 500...599:
                return "Die Kantine hat gerade eine Störung (HTTP \(status))."
            default:
                return "Die Kantine antwortet mit HTTP \(status)."
            }
        case .invalidResponse:
            return "Die Antwort der Kantine war nicht lesbar."
        }
    }
}

public struct KonkaappsClient: Sendable {
    private let credentialsStore: any KonkaappsCredentialsStoring
    private let session: URLSession
    private let baseURL = "https://api.konkaapps.de/kms-mt-webservices/webresources"

    public static let outletHamburg = 8501
    public static let spracheDeutsch = 1

    public init(
        credentialsStore: any KonkaappsCredentialsStoring = KeychainKonkaappsCredentialsStore(),
        session: URLSession = .shared
    ) {
        self.credentialsStore = credentialsStore
        self.session = session
    }

    public func speiseplan(
        outletID: Int = outletHamburg, spracheID: Int = spracheDeutsch
    ) async throws -> [Gericht] {
        let data = try await get("entity.speiseplanadvanced/getdata/\(outletID)/\(spracheID)")
        return Self.parseGerichte(from: data)
    }

    public func referenz(_ art: Referenzart) async throws -> [Int: String] {
        let data = try await get(art.pfad)
        return Self.parseReferenz(from: data)
    }

    public enum Referenzart: String, Sendable, CaseIterable {
        case allergene, zusatzstoffe, gerichtkategorie, gerichtmerkmal
        var pfad: String { "entity.\(rawValue)" }
    }

    private func get(_ pfad: String) async throws -> Data {
        guard let creds = try? credentialsStore.load(), creds.basicAuth.isEmpty == false else {
            throw KonkaappsError.notConnected
        }
        guard let url = URL(string: "\(baseURL)/\(pfad)") else { throw KonkaappsError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("application/json;", forHTTPHeaderField: "Accept")
        request.setValue(creds.basicAuth, forHTTPHeaderField: "Authorization")
        request.setValue("1", forHTTPHeaderField: "x-languagetype")
        request.setValue("RTLGRP", forHTTPHeaderField: "x-customer-code")
        request.setValue("1", forHTTPHeaderField: "x-api-mt-platform")
        request.setValue("MTA3.51.0", forHTTPHeaderField: "x-api-mt-version")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KonkaappsError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw KonkaappsError.httpError(http.statusCode)
        }
        return data
    }

    static func parseGerichte(from data: Data) -> [Gericht] {
        guard let wochen = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return [] }
        return wochen.flatMap { woche -> [Gericht] in
            (woche["speiseplanGerichtData"] as? [[String: Any]] ?? []).compactMap(parseGericht)
        }
    }

    static func parseGericht(_ roh: [String: Any]) -> Gericht? {
        let header = roh["speiseplanAdvancedGericht"] as? [String: Any] ?? [:]
        guard let name = text(header["gerichtname"]), name.isEmpty == false,
              let date = parseDatum(header["datum"]) else { return nil }
        let zusatz = roh["zusatzinformationen"] as? [String: Any] ?? [:]

        return Gericht(
            id: text(header["id"]) ?? "\(name)-\(date.timeIntervalSince1970)",
            date: date,
            name: name,
            kategorieID: zahl(header["gerichtkategorieID"]).map(Int.init),
            mitarbeiterpreis: dezimal(zusatz["mitarbeiterpreisDecimal2"]),
            gaestepreis: dezimal(zusatz["gaestepreisDecimal2"]),

            imageUrl: text(zusatz["gerichtImage"]).flatMap { URL(string: $0) },
            allergeneIDs: SpeiseplanFilter.parseIDs(text(roh["allergeneIds"])),
            zusatzstoffeIDs: SpeiseplanFilter.parseIDs(text(roh["zusatzstoffeIds"])),
            merkmaleIDs: SpeiseplanFilter.parseIDs(text(roh["gerichtmerkmaleIds"])),
            naehrwerte: Naehrwerte(
                kcal: zahl(zusatz["nwkcalInteger"]).map(Int.init),
                fett: zahl(zusatz["nwfettDecimal1"]),
                kohlenhydrate: zahl(zusatz["nwkohlenhydrateDecimal1"]),
                eiweiss: zahl(zusatz["nweiweissDecimal1"])))
    }

    static func parseReferenz(from data: Data) -> [Int: String] {
        guard let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return [:] }
        var card: [Int: String] = [:]
        for entry in list {
            guard let id = zahl(entry["id"]).map(Int.init) else { continue }
            let candidates = ["bezeichnung", "name", "titel", "kurzbezeichnung", "beschreibung"]
            if let label = candidates.lazy.compactMap({ text(entry[$0]) })
                .first(where: { $0.isEmpty == false }) {
                card[id] = label
            }
        }
        return card
    }

    static func parseDatum(_ value: Any?) -> Date? {
        if let millis = zahl(value), millis > 100_000_000 {
            return Date(timeIntervalSince1970: millis / 1000)
        }
        guard let roh = text(value), roh.isEmpty == false else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: roh) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: roh) { return d }
        let nurTag = DateFormatter()
        nurTag.locale = Locale(identifier: "en_US_POSIX")
        nurTag.dateFormat = "yyyy-MM-dd"
        return nurTag.date(from: String(roh.prefix(10)))
    }

    static func text(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    static func zahl(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    static func dezimal(_ value: Any?) -> Decimal? {
        zahl(value).map { Decimal($0) }
    }
}
