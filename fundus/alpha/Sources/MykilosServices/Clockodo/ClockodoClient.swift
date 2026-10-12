import Foundation
import MykilosKit

public struct ClockodoTimeEntry: Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var durationSeconds: Int

    public init(id: String, label: String, durationSeconds: Int) {
        self.id = id
        self.label = label
        self.durationSeconds = durationSeconds
    }
}

public enum ClockodoError: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed
}

extension ClockodoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Nicht mit Clockodo verbunden — E-Mail + API-Key in Einstellungen → Privat eintragen."
        case .invalidResponse:
            return "Unerwartete Antwort von Clockodo."
        case .httpError(let status):
            let zusatz = (status == 401 || status == 403)
                ? " — der API-Key wird abgelehnt. Key in Clockodo (Einstellungen → API) prüfen."
                : ""
            return "Clockodo antwortet mit HTTP \(status)\(zusatz)."
        case .decodingFailed:
            return "Die Antwort von Clockodo war nicht lesbar (unerwartetes Format)."
        }
    }
}

public protocol ClockodoFetching: Sendable {
    func todaysEntries(userID: Int?) async throws -> [ClockodoTimeEntry]
}

public protocol ClockodoStammdatenFetching: Sendable {
    func listeKunden() async throws -> [ClockodoKunde]
    func listeProjekte() async throws -> [ClockodoProjekt]
    func listeLeistungen() async throws -> [ClockodoLeistung]

    func entries(seit: Date, bis: Date, userID: Int?) async throws -> [ClockodoEintrag]
}

public protocol ClockodoBooking: Sendable {
    func createEntry(
        customersID: Int, servicesID: Int, projectsID: Int?, timeSince: Date, timeUntil: Date, billable: Bool, text: String?,
        nutzerHatJetztBestaetigt: Bool
    ) async throws -> String

    func loescheEintrag(id: Int, nutzerHatJetztBestaetigt: Bool) async throws

    func aktualisiereEintragText(id: Int, text: String, nutzerHatJetztBestaetigt: Bool) async throws

    func setzeBillable(id: Int, billable: Bool, nutzerHatJetztBestaetigt: Bool) async throws
}

public struct ClockodoClient: ClockodoFetching, ClockodoBooking, ClockodoStammdatenFetching {
    private let credentialsStore: ClockodoCredentialsStoring
    private let session: URLSession
    private let baseURL = "https://my.clockodo.com/api/v2/entries"
    private let kundenURL = "https://my.clockodo.com/api/v2/customers"
    private let projekteURL = "https://my.clockodo.com/api/v2/projects"
    private let leistungenURL = "https://my.clockodo.com/api/v2/services"

    public init(
        credentialsStore: ClockodoCredentialsStoring = KeychainClockodoCredentialsStore(),
        session: URLSession = .shared
    ) {
        self.credentialsStore = credentialsStore
        self.session = session
    }

    private func autorisierteRequest(_ url: URL) throws -> URLRequest {
        guard let credentials = try? credentialsStore.load() else { throw ClockodoError.notConnected }
        var request = URLRequest(url: url)
        request.setValue(credentials.email, forHTTPHeaderField: "X-ClockodoApiUser")
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-ClockodoApiKey")
        request.setValue("ALPHA;\(credentials.email)", forHTTPHeaderField: "X-Clockodo-External-Application")
        return request
    }

    public func listeKunden() async throws -> [ClockodoKunde] {
        let entities: [ClockodoKundeEntity] = try await ladeAlleSeiten(basisURL: kundenURL, key: "customers")
        return entities.map { ClockodoKunde(id: $0.id, name: $0.name, isActive: $0.active ?? true) }
    }

    public func listeProjekte() async throws -> [ClockodoProjekt] {
        let entities: [ClockodoProjektEntity] = try await ladeAlleSeiten(basisURL: projekteURL, key: "projects")
        return entities.map { ClockodoProjekt(id: $0.id, kundeID: $0.customersID, name: $0.name, isActive: $0.active ?? true) }
    }

    public func listeLeistungen() async throws -> [ClockodoLeistung] {
        let entities: [ClockodoLeistungEntity] = try await ladeAlleSeiten(basisURL: leistungenURL, key: "services")
        return entities.map { ClockodoLeistung(id: $0.id, name: $0.name, isActive: $0.active ?? true) }
    }

    private func ladeAlleSeiten<T: Decodable>(basisURL: String, key: String) async throws -> [T] {
        var page = 1
        var alle: [T] = []
        while true {
            guard var comps = URLComponents(string: basisURL) else { throw ClockodoError.invalidResponse }
            comps.queryItems = [URLQueryItem(name: "page", value: String(page))]
            guard let url = comps.url else { throw ClockodoError.invalidResponse }
            let request = try autorisierteRequest(url)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ClockodoError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { throw ClockodoError.httpError(http.statusCode) }
            let (items, countPages): ([T], Int) = try Self.parseListe(from: data, key: key)
            alle += items
            if page >= countPages { break }
            page += 1
        }
        return alle
    }

    static func parseListe<T: Decodable>(from data: Data, key: String) throws -> (items: [T], countPages: Int) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClockodoError.decodingFailed
        }
        let rohArray = (root["data"] as? [[String: Any]]) ?? (root[key] as? [[String: Any]]) ?? []
        let paging = root["paging"] as? [String: Any]
        let countPages = (paging?["count_pages"] as? Int) ?? 1
        do {
            let arrData = try JSONSerialization.data(withJSONObject: rohArray)
            let items = try JSONDecoder().decode([T].self, from: arrData)
            return (items, countPages)
        } catch {
            throw ClockodoError.decodingFailed
        }
    }

    static func parseKunden(from data: Data) throws -> [ClockodoKunde] {
        let (items, _): ([ClockodoKundeEntity], Int) = try parseListe(from: data, key: "customers")
        return items.map { ClockodoKunde(id: $0.id, name: $0.name, isActive: $0.active ?? true) }
    }
    static func parseProjekte(from data: Data) throws -> [ClockodoProjekt] {
        let (items, _): ([ClockodoProjektEntity], Int) = try parseListe(from: data, key: "projects")
        return items.map { ClockodoProjekt(id: $0.id, kundeID: $0.customersID, name: $0.name, isActive: $0.active ?? true) }
    }
    static func parseLeistungen(from data: Data) throws -> [ClockodoLeistung] {
        let (items, _): ([ClockodoLeistungEntity], Int) = try parseListe(from: data, key: "services")
        return items.map { ClockodoLeistung(id: $0.id, name: $0.name, isActive: $0.active ?? true) }
    }

    public func entries(seit: Date, bis: Date, userID: Int? = nil) async throws -> [ClockodoEintrag] {
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
        var page = 1
        var alle: [ClockodoEintragEntity] = []
        while true {
            guard var comps = URLComponents(string: baseURL) else { throw ClockodoError.invalidResponse }
            var abfrage = [
                URLQueryItem(name: "time_since", value: iso.string(from: seit)),
                URLQueryItem(name: "time_until", value: iso.string(from: bis)),
                URLQueryItem(name: "page", value: String(page))
            ]
            if let userID { abfrage.append(URLQueryItem(name: "filter[users_id]", value: String(userID))) }
            comps.queryItems = abfrage
            guard let url = comps.url else { throw ClockodoError.invalidResponse }
            let request = try autorisierteRequest(url)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ClockodoError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { throw ClockodoError.httpError(http.statusCode) }
            let (items, countPages): ([ClockodoEintragEntity], Int) = try Self.parseListe(from: data, key: "entries")
            alle += items
            if page >= countPages { break }
            page += 1
        }
        return Self.zuEintraegen(alle)
    }

    static func parseEintraege(from data: Data) throws -> [ClockodoEintrag] {
        let (items, _): ([ClockodoEintragEntity], Int) = try parseListe(from: data, key: "entries")
        return zuEintraegen(items)
    }

    private static func zuEintraegen(_ entities: [ClockodoEintragEntity]) -> [ClockodoEintrag] {
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
        return entities.map { e in
            ClockodoEintrag(
                id: e.id, kundeID: e.customersID, projektID: e.projectsID, leistungID: e.servicesID,
                text: e.text, start: e.timeSince.flatMap { iso.date(from: $0) } ?? Date(timeIntervalSince1970: 0),
                dauerSekunden: e.duration ?? 0, billable: (e.billable ?? 1) >= 1)
        }
    }

    public func loescheEintrag(id: Int, nutzerHatJetztBestaetigt: Bool) async throws {
        try ClockodoWriteGate.assertZeitEintragErlaubt(nutzerHatJetztBestaetigt: nutzerHatJetztBestaetigt)
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw ClockodoError.invalidResponse }
        var request = try autorisierteRequest(url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClockodoError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClockodoError.httpError(http.statusCode) }
    }

    public func aktualisiereEintragText(id: Int, text: String, nutzerHatJetztBestaetigt: Bool) async throws {
        try await putEintrag(id: id, felder: ["text": text], nutzerHatJetztBestaetigt: nutzerHatJetztBestaetigt)
    }

    public func setzeBillable(id: Int, billable: Bool, nutzerHatJetztBestaetigt: Bool) async throws {
        try await putEintrag(id: id, felder: ["billable": billable ? 1 : 0], nutzerHatJetztBestaetigt: nutzerHatJetztBestaetigt)
    }

    private func putEintrag(id: Int, felder: [String: Any], nutzerHatJetztBestaetigt: Bool) async throws {
        try ClockodoWriteGate.assertZeitEintragErlaubt(nutzerHatJetztBestaetigt: nutzerHatJetztBestaetigt)
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw ClockodoError.invalidResponse }
        var request = try autorisierteRequest(url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: felder)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClockodoError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClockodoError.httpError(http.statusCode) }
    }

    public func todaysEntries(userID: Int?) async throws -> [ClockodoTimeEntry] {
        guard let url = Self.buildEntriesURL(baseURL: baseURL, now: Date(), userID: userID) else {
            throw ClockodoError.invalidResponse
        }
        let request = try autorisierteRequest(url)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClockodoError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClockodoError.httpError(http.statusCode) }

        return try Self.parseEntries(from: data)
    }

    public func createEntry(
        customersID: Int, servicesID: Int, projectsID: Int? = nil, timeSince: Date, timeUntil: Date, billable: Bool, text: String? = nil,
        nutzerHatJetztBestaetigt: Bool
    ) async throws -> String {
        try ClockodoWriteGate.assertZeitEintragErlaubt(nutzerHatJetztBestaetigt: nutzerHatJetztBestaetigt)
        guard let url = URL(string: baseURL) else { throw ClockodoError.invalidResponse }

        var request = try autorisierteRequest(url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.buildCreateEntryBody(
            customersID: customersID, servicesID: servicesID, projectsID: projectsID,
            timeSince: timeSince, timeUntil: timeUntil, billable: billable, text: text
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClockodoError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClockodoError.httpError(http.statusCode) }

        return try Self.parseCreateEntryResponse(from: data)
    }

    static func buildEntriesURL(baseURL: String, now: Date, userID: Int? = nil) -> URL? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let startOfDay = calendar.startOfDay(for: now)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: baseURL)
        var abfrage = [
            URLQueryItem(name: "time_since", value: isoFormatter.string(from: startOfDay)),
            URLQueryItem(name: "time_until", value: isoFormatter.string(from: now))
        ]
        if let userID { abfrage.append(URLQueryItem(name: "filter[users_id]", value: String(userID))) }
        components?.queryItems = abfrage
        return components?.url
    }

    static func parseEntries(from data: Data) throws -> [ClockodoTimeEntry] {
        do {
            let decoded = try JSONDecoder().decode(ClockodoEntriesResponse.self, from: data)
            return decoded.entries.map { entry in
                ClockodoTimeEntry(
                    id: String(entry.id),
                    label: entry.projectsName ?? entry.customersName ?? "(ohne Projekt)",
                    durationSeconds: entry.duration ?? 0
                )
            }
        } catch {
            throw ClockodoError.decodingFailed
        }
    }

    static func buildCreateEntryBody(
        customersID: Int, servicesID: Int, projectsID: Int? = nil, timeSince: Date, timeUntil: Date, billable: Bool, text: String?
    ) -> Data {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        var payload: [String: Any] = [
            "customers_id": customersID,
            "services_id": servicesID,
            "billable": billable ? 1 : 0,
            "time_since": isoFormatter.string(from: timeSince),
            "time_until": isoFormatter.string(from: timeUntil)
        ]
        if let projectsID {
            payload["projects_id"] = projectsID
        }
        if let text, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            payload["text"] = text
        }
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    static func parseCreateEntryResponse(from data: Data) throws -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = obj["entry"] as? [String: Any],
              let id = entry["id"] else {
            throw ClockodoError.decodingFailed
        }
        return String(describing: id)
    }
}

private struct ClockodoKundeEntity: Decodable {
    var id: Int
    var name: String
    var active: Bool?
}
private struct ClockodoProjektEntity: Decodable {
    var id: Int
    var name: String
    var active: Bool?
    var customersID: Int
    enum CodingKeys: String, CodingKey {
        case id, name, active
        case customersID = "customers_id"
    }
}
private struct ClockodoLeistungEntity: Decodable {
    var id: Int
    var name: String
    var active: Bool?
}

private struct ClockodoEntriesResponse: Decodable {
    var entries: [ClockodoEntryEntity]
}

private struct ClockodoEintragEntity: Decodable {
    var id: Int
    var customersID: Int
    var projectsID: Int?
    var servicesID: Int
    var text: String?
    var timeSince: String?
    var duration: Int?
    var billable: Int?
    enum CodingKeys: String, CodingKey {
        case id, text, duration, billable
        case customersID = "customers_id"
        case projectsID = "projects_id"
        case servicesID = "services_id"
        case timeSince = "time_since"
    }
}

private struct ClockodoEntryEntity: Decodable {
    var id: Int
    var customersName: String?
    var projectsName: String?
    var duration: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case customersName = "customers_name"
        case projectsName = "projects_name"
        case duration
    }
}
