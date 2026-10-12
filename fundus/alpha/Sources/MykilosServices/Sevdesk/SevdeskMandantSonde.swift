import Foundation
import MykilosKit

public protocol SevdeskMandantSondierend: Sendable {
    func sondiere(angebotsNummer: String?) async throws -> SevdeskMandantBefund
}

public struct SevdeskMandantSonde: SevdeskMandantSondierend {
    private let credentialsStore: SevdeskCredentialsStoring
    private let session: URLSession
    private let baseURL = "https://my.sevdesk.de/api/v1"

    public init(
        credentialsStore: SevdeskCredentialsStoring = KeychainSevdeskCredentialsStore(),
        session: URLSession = .shared
    ) {
        self.credentialsStore = credentialsStore
        self.session = session
    }

    public func sondiere(angebotsNummer: String? = nil) async throws -> SevdeskMandantBefund {
        var gaps: [String] = []

        let versionsDaten = try await get(path: "Tools/bookkeepingSystemVersion")
        let version = versionsDaten.flatMap { Self.parseBuchhaltungsVersion(from: $0) }
        if version == nil {
            gaps.append("Buchhaltungs-Version nicht lesbar — Antwort hatte ein unerwartetes Format.")
        }

        var query = [URLQueryItem(name: "orderType", value: "AN"), URLQueryItem(name: "limit", value: "1")]
        if let angebotsNummer, angebotsNummer.isEmpty == false {
            query.append(URLQueryItem(name: "orderNumber", value: angebotsNummer))
        }
        let template = try await get(path: "Order", query: query).flatMap { Self.parseVorlage(from: $0) }
        if template == nil {
            gaps.append(angebotsNummer?.isEmpty == false
                ? "Kein Angebot mit dieser Nummer gefunden — Feld leer lassen nimmt das erste vorhandene."
                : "sevDesk liefert kein Angebot (orderType „AN“) — ohne Vorlage bleiben contactPerson/addressCountry unbekannt.")
        } else {
            if template?.contactPersonID == nil { gaps.append("contactPerson (SevUser-ID) fehlt im Vorlage-Angebot.") }
            if template?.addressCountryID == nil { gaps.append("addressCountry (StaticCountry-ID) fehlt im Vorlage-Angebot.") }
            if template?.taxRate == nil { gaps.append("taxRate fehlt im Vorlage-Angebot.") }
        }

        var einheiten: [SevdeskMandantBefund.Einheit] = []
        var positionsSteuersatz: Double?
        if let orderID = template?.orderID {
            if let data = try await get(path: "Order/\(orderID)/getPositions",
                                        query: [URLQueryItem(name: "embed", value: "unity")]) {
                einheiten = Self.parseEinheiten(from: data)
                positionsSteuersatz = Self.parsePositionsSteuersatz(from: data)
            }
            if einheiten.isEmpty { gaps.append("Keine Einheit (unity) in den Positionen des Vorlage-Angebots lesbar.") }
            if positionsSteuersatz == nil {
                gaps.append("Kein Steuersatz in den Positionen lesbar — der Kopf-Wert allein ist in Version 2.0 unzuverlässig (dort steht 0).")
            }

            if let header = template?.taxRate, let pos = positionsSteuersatz, header != pos {
                gaps.append("Hinweis: Beleg-Kopf meldet \(header) %, die Positionen führen \(pos) % — "
                               + "für neue Positionen gilt \(pos) % (in Version 2.0 führt taxRule, nicht der Kopf-Satz).")
            }
        }

        let naechsteNummer: String? = await {
            guard let data = try? await get(path: "Order/Factory/getNextOrderNumber", query: [
                URLQueryItem(name: "orderType", value: "AN"),
                URLQueryItem(name: "useNextNumber", value: "false")
            ]) else { return nil }
            return Self.parseNaechsteBelegnummer(from: data)
        }()
        if naechsteNummer == nil {
            gaps.append("Nächste Belegnummer nicht ermittelbar (Order/Factory/getNextOrderNumber) — "
                           + "sevDesk verlangt aber eine Angebotsnummer. Ohne sie kein Entwurf.")
        }

        return SevdeskMandantBefund(
            buchhaltungsVersion: version, template: template, einheiten: einheiten,
            positionsSteuersatz: positionsSteuersatz, naechsteBelegnummer: naechsteNummer,
            gaps: gaps)
    }

    public func reserviereBelegnummer(orderType: String = "AN") async throws -> String? {
        guard let data = try await get(path: "Order/Factory/getNextOrderNumber", query: [
            URLQueryItem(name: "orderType", value: orderType),
            URLQueryItem(name: "useNextNumber", value: "true")
        ]) else { return nil }
        guard let number = Self.parseNaechsteBelegnummer(from: data) else {
            throw SevdeskApiFehler(
                status: 200,
                message: "Antwort auf die Nummern-Reservierung nicht lesbar — vermutlich wurde "
                    + "trotzdem eine Nummer reserviert. Bitte den Nummernkreis in sevDesk prüfen.")
        }
        return number
    }

    public func loeseKontaktAuf(customerNumber: String) async throws -> SevdeskKontaktTreffer {
        let number = customerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard number.isEmpty == false else { return .keiner }
        guard let data = try await get(path: "Contact", query: [
            URLQueryItem(name: "customerNumber", value: number),
            URLQueryItem(name: "depth", value: "1")
        ]) else { return .keiner }
        return Self.parseKontaktTreffer(from: data, angefragteNummer: number)
    }

    public func loeseKontaktAuf(name: String) async throws -> SevdeskKontaktTreffer {
        let gesucht = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard gesucht.isEmpty == false else { return .keiner }
        guard let data = try await get(path: "Contact", query: [
            URLQueryItem(name: "name", value: gesucht),
            URLQueryItem(name: "depth", value: "1")
        ]) else { return .keiner }
        return Self.parseKontaktTrefferNachName(from: data, angefragterName: gesucht)
    }

    static func parseKontaktTrefferNachName(
        from data: Data, angefragterName: String
    ) -> SevdeskKontaktTreffer {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["objects"] as? [[String: Any]]
        else { return .keiner }

        let gesucht = angefragterName.trimmingCharacters(in: .whitespacesAndNewlines)

        let candidates: [SevdeskKontaktTreffer.Kandidat] = list.compactMap { objekt in
            guard let id = text(objekt["id"]), id.isEmpty == false,
                  let name = kontaktName(objekt),
                  name.caseInsensitiveCompare(gesucht) == .orderedSame
            else { return nil }
            let parent = (objekt["parent"] as? [String: Any]).flatMap { text($0["id"]) }
            return .init(id: id, name: name, istAnsprechpartner: parent?.isEmpty == false)
        }

        switch candidates.count {
        case 0: return .keiner
        case 1:
            let k = candidates[0]
            return k.istAnsprechpartner ? .nurAnsprechpartner(k) : .eindeutig(id: k.id, name: k.name)
        default: return .mehrdeutig(candidates)
        }
    }

    static func parseKontaktTreffer(
        from data: Data, angefragteNummer: String
    ) -> SevdeskKontaktTreffer {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["objects"] as? [[String: Any]]
        else { return .keiner }

        let gesucht = angefragteNummer.trimmingCharacters(in: .whitespacesAndNewlines)

        let candidates: [SevdeskKontaktTreffer.Kandidat] = list.compactMap { objekt in
            guard let id = text(objekt["id"]), id.isEmpty == false else { return nil }

            guard let gemeldet = text(objekt["customerNumber"]),
                  gemeldet.trimmingCharacters(in: .whitespacesAndNewlines) == gesucht
            else { return nil }

            let parent = (objekt["parent"] as? [String: Any]).flatMap { text($0["id"]) }
            return .init(id: id, name: kontaktName(objekt),
                         istAnsprechpartner: parent?.isEmpty == false)
        }

        switch candidates.count {
        case 0: return .keiner
        case 1:
            let k = candidates[0]
            return k.istAnsprechpartner ? .nurAnsprechpartner(k) : .eindeutig(id: k.id, name: k.name)
        default: return .mehrdeutig(candidates)
        }
    }

    static func kontaktName(_ objekt: [String: Any]) -> String? {
        if let name = text(objekt["name"]), name.isEmpty == false { return name }
        let teile = [text(objekt["surename"]), text(objekt["familyname"])]
            .compactMap { $0 }.filter { $0.isEmpty == false }
        return teile.isEmpty ? nil : teile.joined(separator: " ")
    }

    public func lerneKundenKategorie() async throws -> String? {
        guard let data = try await get(path: "Contact", query: [
            URLQueryItem(name: "depth", value: "1")
        ]) else { return nil }
        return Self.parseKundenKategorie(from: data)
    }

    static func parseKundenKategorie(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["objects"] as? [[String: Any]]
        else { return nil }
        for objekt in list {
            if let kategorie = objekt["category"] as? [String: Any],
               let id = text(kategorie["id"]), id.isEmpty == false {
                return id
            }
        }
        return nil
    }

    private func get(path: String, query: [URLQueryItem] = []) async throws -> Data? {
        guard let credentials = try? credentialsStore.load() else { throw SevdeskError.notConnected }
        guard let url = SevdeskReadClient.buildURL(baseURL: baseURL, path: path, query: query) else {
            throw SevdeskError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SevdeskError.invalidResponse }
        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode) else { throw SevdeskError.httpError(http.statusCode) }
        return data
    }

    static func parseBuchhaltungsVersion(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }

        if let objekt = root["objects"] as? [String: Any] { return text(objekt["version"]) }
        if let list = root["objects"] as? [[String: Any]] { return text(list.first?["version"]) }
        return nil
    }

    static func parseVorlage(from data: Data) -> SevdeskMandantBefund.Vorlage? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let objekte = root["objects"] as? [[String: Any]],
              let order = objekte.first,
              let orderID = text(order["id"]) else { return nil }
        return SevdeskMandantBefund.Vorlage(
            orderID: orderID,
            orderNumber: text(order["orderNumber"]),
            contactID: text((order["contact"] as? [String: Any])?["id"]),
            contactPersonID: text((order["contactPerson"] as? [String: Any])?["id"]),
            addressCountryID: text((order["addressCountry"] as? [String: Any])?["id"]),
            taxRuleID: text((order["taxRule"] as? [String: Any])?["id"]),
            taxRate: zahl(order["taxRate"]),
            taxType: text(order["taxType"]),
            currency: text(order["currency"]))
    }

    static func parseEinheiten(from data: Data) -> [SevdeskMandantBefund.Einheit] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let objekte = root["objects"] as? [[String: Any]] else { return [] }
        var gesehen = Set<String>()
        var result: [SevdeskMandantBefund.Einheit] = []
        for pos in objekte {
            guard let unity = pos["unity"] as? [String: Any],
                  let id = text(unity["id"]) else { continue }

            guard let name = text(unity["name"]) ?? text(unity["translationCode"]), name.isEmpty == false else { continue }
            if gesehen.insert(id).inserted { result.append(.init(id: id, name: name)) }
        }
        return result
    }

    static func parseNaechsteBelegnummer(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if let direkt = root["objects"] as? String, direkt.isEmpty == false { return direkt }
        if let objekt = root["objects"] as? [String: Any] {
            for key in ["orderNumber", "nextOrderNumber", "number", "value"] {
                if let t = text(objekt[key]) { return t }
            }
        }
        if let list = root["objects"] as? [String], let erster = list.first, erster.isEmpty == false { return erster }
        return nil
    }

    static func parsePositionsSteuersatz(from data: Data) -> Double? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let objekte = root["objects"] as? [[String: Any]] else { return nil }
        let saetze = objekte.compactMap { zahl($0["taxRate"]) }
        guard saetze.isEmpty == false else { return nil }
        let haeufigkeit = saetze.reduce(into: [Double: Int]()) { $0[$1, default: 0] += 1 }
        return haeufigkeit.max { a, b in
            a.value != b.value ? a.value < b.value : a.key < b.key
        }?.key
    }

    static func text(_ value: Any?) -> String? {
        if let s = value as? String { return s.isEmpty ? nil : s }
        if let i = value as? Int { return String(i) }
        if let d = value as? Double { return d == d.rounded() ? String(Int(d)) : String(d) }
        return nil
    }

    static func zahl(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }
}

public struct SevdeskBelegStand: Sendable, Equatable {
    public let status: Int?
    public let update: String?
    public let contactID: String?
    public init(status: Int?, update: String?, contactID: String?) {
        self.status = status; self.update = update; self.contactID = contactID
    }
}

extension SevdeskMandantSonde {
    public func fetchReceiptState(orderID: String) async throws -> SevdeskBelegStand? {
        guard let data = try await get(path: "Order/\(orderID)", query: []) else { return nil }
        return Self.parseBelegStand(from: data)
    }

    static func parseBelegStand(from data: Data) -> SevdeskBelegStand? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let objekt: [String: Any]?
        if let list = root["objects"] as? [[String: Any]] { objekt = list.first } else if let einzeln = root["objects"] as? [String: Any] { objekt = einzeln } else { objekt = nil }
        guard let objekt else { return nil }
        let kontakt = (objekt["contact"] as? [String: Any]).flatMap { text($0["id"]) }
        return SevdeskBelegStand(
            status: zahl(objekt["status"]).map(Int.init),
            update: text(objekt["update"]),
            contactID: kontakt)
    }
}
