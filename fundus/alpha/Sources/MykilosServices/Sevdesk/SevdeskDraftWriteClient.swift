import Foundation
import MykilosKit

public struct SevdeskDraftWriteResult: Equatable, Sendable {
    public let sevdeskOrderID: String
    public let orderNumber: String?
}

public struct SevdeskApiFehler: Error, Equatable, Sendable {
    public let status: Int

    public let message: String

    public init(status: Int, message: String) {
        self.status = status
        self.message = message
    }
}

public protocol SevdeskDraftWriting: Sendable {
    func createOfferDraft(_ package: CommercialDraftPackage) async throws -> SevdeskDraftWriteResult
    func updateOwnOfferDraft(sevdeskOrderID: String, _ package: CommercialDraftPackage) async throws -> SevdeskDraftWriteResult
}

public struct SevdeskDraftWriteClient: SevdeskDraftWriting {
    private let credentialsStore: SevdeskCredentialsStoring
    private let session: URLSession
    private let kontext: SevdeskSendeKontext
    private let baseURL = "https://my.sevdesk.de/api/v1"

    public init(
        credentialsStore: SevdeskCredentialsStoring = KeychainSevdeskCredentialsStore(),
        session: URLSession = .shared,
        kontext: SevdeskSendeKontext
    ) {
        self.credentialsStore = credentialsStore
        self.session = session
        self.kontext = kontext
    }

    public func createOfferDraft(_ package: CommercialDraftPackage) async throws -> SevdeskDraftWriteResult {
        try await saveOrder(package, existingOrderID: nil)
    }

    public func updateOwnOfferDraft(sevdeskOrderID: String, _ package: CommercialDraftPackage) async throws -> SevdeskDraftWriteResult {
        try await saveOrder(package, existingOrderID: sevdeskOrderID)
    }

    private func saveOrder(_ package: CommercialDraftPackage, existingOrderID: String?) async throws -> SevdeskDraftWriteResult {
        guard let credentials = try? credentialsStore.load() else { throw SevdeskError.notConnected }
        guard let url = URL(string: "\(baseURL)/Order/Factory/saveOrder") else { throw SevdeskError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: Self.buildSaveOrderBody(package: package, existingOrderID: existingOrderID, kontext: kontext))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SevdeskError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw SevdeskApiFehler(status: http.statusCode,
                                   message: Self.fehlerMeldung(aus: data))
        }
        return try Self.parseSaveOrderResponse(from: data)
    }

    static func buildSaveOrderBody(
        package: CommercialDraftPackage, existingOrderID: String?, kontext: SevdeskSendeKontext
    ) -> [String: Any] {
        var order: [String: Any] = [

            "objectName": "Order",
            "contact": ["id": package.contactID, "objectName": "Contact"],
            "orderDate": Self.sevdeskDatum(package.createdAt),
            "status": 100,
            "orderType": "AN",
            "currency": package.currency,
            "header": package.title,

            "customerInternalNote": Self.kostenstelle(aus: package.projektCode),

            "addressCountry": ["id": kontext.addressCountryID, "objectName": "StaticCountry"],
            "contactPerson": ["id": kontext.contactPersonID, "objectName": "SevUser"],
            "taxRate": kontext.taxRate,

            "taxRule": ["id": kontext.taxRuleID, "objectName": "TaxRule"],
            "taxText": kontext.taxText,
            "taxType": kontext.taxType,

            "version": 0,
            "mapAll": true,
            "showNet": kontext.showNet
        ]

        if let number = kontext.orderNumber, number.isEmpty == false { order["orderNumber"] = number }

        if let header = package.einleitungsText, header.isEmpty == false { order["headText"] = htmlAusText(header) }

        if let footer = kontext.fussText, footer.isEmpty == false { order["footText"] = htmlAusText(footer) }

        if let adresse = kontext.adresse, adresse.isEmpty == false { order["address"] = adresse }
        if let existingOrderID {
            order["id"] = existingOrderID
        }

        let positionen: [[String: Any]] = package.positionen
            .compactMap { position -> (CommercialDraftPosition, Decimal)? in
                guard let vk = position.vkNettoEinzel else { return nil }
                return (position, vk)
            }
            .enumerated()
            .map { index, paar in
                let (position, vk) = paar
                var felder: [String: Any] = [

                    "objectName": "OrderPos",
                    "mapAll": true,
                    "quantity": NSDecimalNumber(decimal: position.quantity).doubleValue,
                    "price": NSDecimalNumber(decimal: vk).doubleValue,
                    "name": position.label,
                    "positionNumber": index,

                    "unity": ["id": kontext.unityID(fuerEinheit: position.einheitText),
                              "objectName": "Unity"],
                    "taxRate": kontext.taxRate
                ]
                if let beschreibung = position.beschreibung, beschreibung.isEmpty == false {
                    felder["text"] = beschreibung
                }

                if let partID = position.sevdeskPartID, partID.isEmpty == false {
                    felder["part"] = ["id": partID, "objectName": "Part"]
                }

                if let rabatt = position.rabattProzent, rabatt != 0 {
                    felder["discount"] = NSDecimalNumber(decimal: rabatt).doubleValue
                }

                if position.kind == .optionalItem { felder["optional"] = true }
                return felder
            }

        return ["order": order, "orderPosSave": positionen]
    }

    static func htmlAusText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    static func kostenstelle(aus projektCode: String) -> String {
        Projektnummer(parsing: projektCode)?.driveFormat ?? projektCode
    }

    static func sevdeskDatum(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: date)
    }

    static func fehlerMeldung(aus data: Data) -> String {
        if let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let error = root["error"] as? [String: Any] {
                let text = error["message"] as? String
                let code = error["code"].map { "\($0)" }
                let teile = [text, code.map { "(sevDesk-Code \($0))" }].compactMap { $0 }
                if teile.isEmpty == false { return teile.joined(separator: " ") }
            }
            if let text = root["message"] as? String, text.isEmpty == false { return text }
        }
        let roh = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return roh.isEmpty ? "ohne Begründung im Antwort-Body" : String(roh.prefix(600))
    }

    static func parseSaveOrderResponse(from data: Data) throws -> SevdeskDraftWriteResult {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw SevdeskError.decodingFailed
        }

        let container: [String: Any]
        if let objekt = root["objects"] as? [String: Any] { container = objekt } else if let list = root["objects"] as? [[String: Any]], let erstes = list.first { container = erstes } else { container = root }

        let order = (container["order"] as? [String: Any]) ?? container
        guard let id = value(order["id"]) else { throw SevdeskError.decodingFailed }
        return SevdeskDraftWriteResult(sevdeskOrderID: id, orderNumber: value(order["orderNumber"]))
    }

    static func value(_ roh: Any?) -> String? {
        if let s = roh as? String { return s.isEmpty ? nil : s }
        if let i = roh as? Int { return String(i) }
        if let d = roh as? Double { return d == d.rounded() ? String(Int(d)) : String(d) }
        return nil
    }
}
