import Foundation
import MykilosKit

public struct SevdeskKontaktWriteClient: Sendable {
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

    public struct NeuerKontakt: Sendable, Equatable {
        public let id: String
        public let displayName: String
        public init(id: String, displayName: String) { self.id = id; self.displayName = displayName }
    }

    public func createContact(
        name: String, istOrganisation: Bool, customerNumber: String?, kategorieID: String
    ) async throws -> NeuerKontakt {
        guard let credentials = try? credentialsStore.load() else { throw SevdeskError.notConnected }
        guard let url = URL(string: "\(baseURL)/Contact") else { throw SevdeskError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: Self.buildCreateContactBody(
                name: name, istOrganisation: istOrganisation,
                customerNumber: customerNumber, kategorieID: kategorieID))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SevdeskError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw SevdeskApiFehler(
                status: http.statusCode,
                message: SevdeskDraftWriteClient.fehlerMeldung(aus: data))
        }
        guard let kontakt = Self.parseNeuerKontakt(from: data, fallbackName: name) else {
            throw SevdeskApiFehler(
                status: http.statusCode,
                message: "Kontakt vermutlich angelegt, aber die Antwort ist nicht lesbar — "
                    + "bitte in sevDesk prüfen, bevor erneut angelegt wird.")
        }
        return kontakt
    }

    static func buildCreateContactBody(
        name: String, istOrganisation: Bool, customerNumber: String?, kategorieID: String
    ) -> [String: Any] {
        var body: [String: Any] = [
            "objectName": "Contact",
            "mapAll": true,
            "category": ["id": kategorieID, "objectName": "Category"]
        ]
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if istOrganisation {
            body["name"] = sauber
        } else {
            let teile = sauber.split(separator: " ")
            if teile.count >= 2 {
                body["familyname"] = String(teile.last ?? "")
                body["surename"] = teile.dropLast().joined(separator: " ")
            } else {
                body["familyname"] = sauber
            }
        }
        if let number = customerNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
           number.isEmpty == false {
            body["customerNumber"] = number
        }
        return body
    }

    static func parseNeuerKontakt(from data: Data, fallbackName: String) -> NeuerKontakt? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let objekt: [String: Any]?
        if let einzeln = root["objects"] as? [String: Any] { objekt = einzeln } else if let list = root["objects"] as? [[String: Any]] { objekt = list.first } else { objekt = nil }
        guard let objekt, let id = SevdeskMandantSonde.text(objekt["id"]), id.isEmpty == false
        else { return nil }
        return NeuerKontakt(
            id: id, displayName: SevdeskMandantSonde.kontaktName(objekt) ?? fallbackName)
    }
}
