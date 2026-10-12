import Foundation
import MykilosKit

public enum AirtableError: Error, LocalizedError, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)

    case validationFailed(Int, String)
    case decodingFailed
    case invalidBaseID(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Airtable nicht verbunden — Personal Access Token in den Einstellungen eintragen."
        case .invalidResponse:
            return "Airtable-Antwort ungültig (keine HTTP-Antwort erhalten)."
        case .httpError(let code):
            return "Airtable-Fehler HTTP \(code)"
        case .validationFailed(let code, let message):
            return "Airtable-Fehler HTTP \(code): \(message)"
        case .decodingFailed:
            return "Airtable-Antwort konnte nicht gelesen werden (Decoding fehlgeschlagen)."
        case .invalidBaseID(let msg):
            return "Schreibschutz verletzt: \(msg)"
        }
    }

    static func throwForFailedResponse(statusCode: Int, body: Data) throws -> Never {
        if let message = Self.extractErrorMessage(from: body) {
            throw AirtableError.validationFailed(statusCode, message)
        }
        throw AirtableError.httpError(statusCode)
    }

    static func extractErrorMessage(from body: Data) -> String? {
        struct ErrorBody: Decodable { struct Inner: Decodable { let type: String?; let message: String? }; let error: Inner? }
        guard let decoded = try? JSONDecoder().decode(ErrorBody.self, from: body) else { return nil }
        if let message = decoded.error?.message, message.isEmpty == false { return message }
        if let type = decoded.error?.type, type.isEmpty == false { return type }
        return nil
    }
}

public protocol AirtableFetching: Sendable {
    func fetchRecords(baseID: String, table: String) async throws -> [[String: AirtableFieldValue]]

    func fetchRecords(baseID: String, table: String, filterByFormula: String?) async throws -> [[String: AirtableFieldValue]]
}

public extension AirtableFetching {
    func fetchRecords(baseID: String, table: String, filterByFormula: String?) async throws -> [[String: AirtableFieldValue]] {
        try await fetchRecords(baseID: baseID, table: table)
    }
}

public protocol AirtableRecordCreating: Sendable {
    func createRecord(baseID: String, table: String, fields: [String: AirtableFieldValue]) async throws -> String
}

public protocol AirtableRecordUpdating: Sendable {
    func updateRecord(baseID: String, table: String, recordID: String, fields: [String: AirtableFieldValue]) async throws
}

public protocol AirtableRecordDeleting: Sendable {
    func deleteRecord(baseID: String, table: String, recordID: String) async throws
}

public struct AirtableAttachment: Sendable, Equatable, Decodable {
    public let id: String?
    public let url: String
    public let filename: String?
    public let size: Int?
    public let type: String?

    public init(id: String? = nil, url: String, filename: String? = nil,
                size: Int? = nil, type: String? = nil) {
        self.id = id
        self.url = url
        self.filename = filename
        self.size = size
        self.type = type
    }
}

public enum AirtableFieldValue: Sendable, Equatable, Decodable {
    case string(String)
    case array([String])
    case number(Double)

    case bool(Bool)

    case attachments([AirtableAttachment])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if let s = try? container.decode(String.self) { self = .string(s); return }

        if let atts = try? container.decode([AirtableAttachment].self) { self = .attachments(atts); return }
        if let a = try? container.decode([String].self) { self = .array(a); return }
        if let n = try? container.decode(Double.self) { self = .number(n); return }
        if container.decodeNil() { self = .null; return }
        self = .null
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var firstAttachmentURL: String? {
        if case .attachments(let list) = self { return list.first?.url }
        return nil
    }

    public var anyStringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n):
            if n.truncatingRemainder(dividingBy: 1) == 0 {
                return String(Int(n))
            }
            return String(n)
        default: return nil
        }
    }

    public var firstArrayValue: String? {
        if case .array(let a) = self { return a.first }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    var jsonValue: Any {
        switch self {
        case .string(let s):      return s
        case .array(let a):       return a
        case .number(let n):      return n
        case .bool(let b):        return b
        case .attachments:        return NSNull()
        case .null:                return NSNull()
        }
    }
}

public struct AirtableClient: AirtableFetching, AirtableRecordCreating, AirtableRecordUpdating, AirtableRecordDeleting {
    private let credentialsStore: AirtableCredentialsStoring
    private let session: URLSession
    private let apiBase = "https://api.airtable.com/v0"

    public static let writableBaseID = CompanySetup.valueOrEmpty("airtable.base.writable_test")

    public static let projektHubBaseID = CompanySetup.valueOrEmpty("airtable.base.projects")
    public static let goldenKundenBaseID = CompanySetup.valueOrEmpty("airtable.base.golden_customers")
    public static let goldenKundenTable = "Kunden (Golden Record)"
    public static let writableTables: Set<String> = [
        "Datenstrom-Handbuch", "Datenstrom-Log"

    ]

    public static let writableMap: [String: Set<String>] = Dictionary([

        (CompanySetup.valueOrEmpty("airtable.base.writable_test"), Set<String>([
            "TEST-Projekte"

        ])),

        (CompanySetup.valueOrEmpty("airtable.base.write_shadow"), Set<String>([
            "Write-Shadow-Log"
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.clockodo_bookings"), Set<String>([
            "Zeitbuchungen"
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.sevdesk_postbox"), Set<String>([
            "Commercial Packages",
            "Commercial Positions",

            "Postbox-Beleg",
            "Postbox-Position"
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.checkout_cart"), Set<String>([
            "Checkouts",

            "Warenkörbe"
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.golden_customers"), Set<String>([
            CompanySetup.valueOrEmpty("airtable.table.golden_customers"),
            CompanySetup.valueOrEmpty("airtable.table.contacts")

        ])),
        (CompanySetup.valueOrEmpty("airtable.base.projects"), Set<String>([
            CompanySetup.valueOrEmpty("airtable.table.projects"),

            CompanySetup.valueOrEmpty("airtable.table.projects_extra_1"),
            CompanySetup.valueOrEmpty("airtable.table.projects_extra_2"),
            CompanySetup.valueOrEmpty("airtable.table.projects_extra_3"),
            CompanySetup.valueOrEmpty("airtable.table.lead_cards"),
            CompanySetup.valueOrEmpty("airtable.table.document_register")
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.questionnaire_intake"), Set<String>([
            CompanySetup.valueOrEmpty("airtable.table.questionnaire_intake"),

            CompanySetup.valueOrEmpty("airtable.table.questionnaire_extra")
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.data_flow"), Set<String>([
            "Datenstrom-Log"
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.clockodo_users"), Set<String>([
            "Clockodo-Nutzer"
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.article_catalog"), Set<String>([
            CompanySetup.valueOrEmpty("airtable.table.article_catalog")

        ])),

        (CompanySetup.valueOrEmpty("airtable.base.own_catalog"), Set<String>([
            CompanySetup.valueOrEmpty("airtable.table.own_catalog_positions"),
            CompanySetup.valueOrEmpty("airtable.table.own_catalog_hourly_rates")
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.estimation_model"), Set<String>([
            CompanySetup.valueOrEmpty("airtable.table.estimation_model")
        ])),

        (CompanySetup.valueOrEmpty("airtable.base.media_library"), Set<String>([
            CompanySetup.valueOrEmpty("airtable.table.media_staging")
        ]))
    ] as [(String, Set<String>)], uniquingKeysWith: { $0.union($1) })

    public static func isWritable(baseID: String, table: String) -> Bool {
        writableMap[baseID]?.contains(table) == true
    }

    public init(
        credentialsStore: AirtableCredentialsStoring = KeychainAirtableCredentialsStore(),
        session: URLSession = .shared
    ) {
        self.credentialsStore = credentialsStore
        self.session = session
    }

    public func fetchRecords(baseID: String, table: String) async throws -> [[String: AirtableFieldValue]] {
        try await fetchRecords(baseID: baseID, table: table, filterByFormula: nil)
    }

    public func fetchRecords(baseID: String, table: String, filterByFormula: String?) async throws -> [[String: AirtableFieldValue]] {
        guard let credentials = try? credentialsStore.load() else {
            throw AirtableError.notConnected
        }

        var allRecords: [[String: AirtableFieldValue]] = []
        var offset: String?

        repeat {
            guard let url = Self.buildListURL(apiBase: apiBase, baseID: baseID, table: table,
                                              offset: offset, filterByFormula: filterByFormula) else {
                throw AirtableError.invalidResponse
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(credentials.pat)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AirtableError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { try AirtableError.throwForFailedResponse(statusCode: http.statusCode, body: data) }

            let page = try Self.parsePage(from: data)
            allRecords.append(contentsOf: page.records)
            offset = page.offset
        } while offset != nil

        return allRecords
    }

    public func fetchRecordIDs(baseID: String, table: String,
                               wherePrimaryField feld: String, equals value: String) async throws -> [String] {
        guard let credentials = try? credentialsStore.load() else { throw AirtableError.notConnected }
        let escaped = value.replacingOccurrences(of: "'", with: "\\'")
        let formel = "{\(feld)}='\(escaped)'"
        let tableEnc = table.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? table
        let formelEnc = formel.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? formel
        guard let url = URL(string: "\(apiBase)/\(baseID)/\(tableEnc)?filterByFormula=\(formelEnc)&pageSize=3") else {
            throw AirtableError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.pat)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AirtableError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            try AirtableError.throwForFailedResponse(statusCode: http.statusCode, body: data)
        }
        struct IDsResponse: Decodable {
            struct Rec: Decodable { let id: String }
            let records: [Rec]
        }
        return (try? JSONDecoder().decode(IDsResponse.self, from: data))?.records.map(\.id) ?? []
    }

    public func createRecord(baseID: String, table: String, fields: [String: AirtableFieldValue]) async throws -> String {
        try await createRecord(baseID: baseID, table: table, fields: fields, typecast: false)
    }

    public func createRecord(baseID: String, table: String, fields: [String: AirtableFieldValue], typecast: Bool) async throws -> String {
        guard Self.isWritable(baseID: baseID, table: table) else {
            throw AirtableError.invalidBaseID("Schreiben in \(table)@\(baseID) nicht erlaubt — Whitelist: \(Self.writableMap)")
        }
        guard let credentials = try? credentialsStore.load() else {
            throw AirtableError.notConnected
        }
        let encoded = table.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? table
        guard let url = URL(string: "\(apiBase)/\(baseID)/\(encoded)") else {
            throw AirtableError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.pat)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["records": [["fields": fields.mapValues(\.jsonValue)]]]
        if typecast { payload["typecast"] = true }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AirtableError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { try AirtableError.throwForFailedResponse(statusCode: http.statusCode, body: data) }
        let decoded = try? JSONDecoder().decode(CreateRecordResponse.self, from: data)
        return decoded?.records.first?.id ?? ""
    }

    public func createRecords(
        baseID: String, table: String, recordsFields: [[String: AirtableFieldValue]]
    ) async throws -> [String] {
        guard recordsFields.isEmpty == false else { return [] }
        guard Self.isWritable(baseID: baseID, table: table) else {
            throw AirtableError.invalidBaseID("Schreiben in \(table)@\(baseID) nicht erlaubt — Whitelist: \(Self.writableMap)")
        }
        guard let credentials = try? credentialsStore.load() else {
            throw AirtableError.notConnected
        }
        let encoded = table.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? table
        guard let url = URL(string: "\(apiBase)/\(baseID)/\(encoded)") else {
            throw AirtableError.invalidResponse
        }

        var alleIDs: [String] = []
        for block in Self.chunked(recordsFields, size: 10) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(credentials.pat)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Any] = ["records": block.map { ["fields": $0.mapValues(\.jsonValue)] }]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AirtableError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { try AirtableError.throwForFailedResponse(statusCode: http.statusCode, body: data) }
            let decoded = try? JSONDecoder().decode(CreateRecordResponse.self, from: data)
            alleIDs.append(contentsOf: decoded?.records.map(\.id) ?? [])
        }
        return alleIDs
    }

    static func chunked<T>(_ array: [T], size: Int) -> [[T]] {
        guard size > 0 else { return array.isEmpty ? [] : [array] }
        var out: [[T]] = []
        var i = array.startIndex
        while i < array.endIndex {
            let ende = array.index(i, offsetBy: size, limitedBy: array.endIndex) ?? array.endIndex
            out.append(Array(array[i..<ende]))
            i = ende
        }
        return out
    }

    public func updateRecord(baseID: String, table: String, recordID: String, fields: [String: AirtableFieldValue]) async throws {
        try await updateRecord(baseID: baseID, table: table, recordID: recordID, fields: fields, typecast: false)
    }

    public func updateRecord(baseID: String, table: String, recordID: String, fields: [String: AirtableFieldValue], typecast: Bool) async throws {
        guard Self.isWritable(baseID: baseID, table: table) else {
            throw AirtableError.invalidBaseID("Schreiben in \(table)@\(baseID) nicht erlaubt — Whitelist: \(Self.writableMap)")
        }
        guard let credentials = try? credentialsStore.load() else {
            throw AirtableError.notConnected
        }
        let encoded = table.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? table
        guard let url = URL(string: "\(apiBase)/\(baseID)/\(encoded)/\(recordID)") else {
            throw AirtableError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(credentials.pat)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["fields": fields.mapValues(\.jsonValue)]
        if typecast { payload["typecast"] = true }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AirtableError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { try AirtableError.throwForFailedResponse(statusCode: http.statusCode, body: data) }
    }

    public static let testDeletableMap: [String: Set<String>] = [:]

    static func isTestDeletable(baseID: String, table: String) -> Bool {
        testDeletableMap[baseID]?.contains(table) == true
    }

    public func deleteRecord(baseID: String, table: String, recordID: String) async throws {
        guard Self.isTestDeletable(baseID: baseID, table: table) else {
            throw AirtableError.invalidBaseID("Löschen in \(table)@\(baseID) nicht erlaubt — TEST-Delete-Whitelist: \(Self.testDeletableMap)")
        }
        guard let credentials = try? credentialsStore.load() else {
            throw AirtableError.notConnected
        }
        let encoded = table.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? table
        guard let url = URL(string: "\(apiBase)/\(baseID)/\(encoded)/\(recordID)") else {
            throw AirtableError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(credentials.pat)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AirtableError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { try AirtableError.throwForFailedResponse(statusCode: http.statusCode, body: data) }
    }

    public static let kontaktFotoFieldID = CompanySetup.valueOrEmpty("airtable.field.contact_photo")

    public static let kontaktFotoBaseID = CompanySetup.valueOrEmpty("airtable.base.golden_customers")

    public func uploadAttachment(
        baseID: String, recordID: String, fieldID: String,
        fileData: Data, filename: String, mimeType: String
    ) async throws -> String {
        guard Self.writableMap[baseID] != nil else {
            throw AirtableError.invalidBaseID("Attachment-Upload nur in Schreib-Whitelist-Bases erlaubt (angefragt: \(baseID)).")
        }
        guard let credentials = try? credentialsStore.load() else {
            throw AirtableError.notConnected
        }
        guard let url = Self.buildUploadAttachmentURL(apiBase: apiBase, baseID: baseID, recordID: recordID, fieldID: fieldID) else {
            throw AirtableError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.pat)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encodeUploadAttachmentPayload(fileData: fileData, filename: filename, mimeType: mimeType)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AirtableError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { try AirtableError.throwForFailedResponse(statusCode: http.statusCode, body: data) }
        guard let uploadedURL = Self.parseUploadAttachmentResponse(from: data) else {
            throw AirtableError.decodingFailed
        }
        return uploadedURL
    }

    static func buildUploadAttachmentURL(apiBase: String, baseID: String, recordID: String, fieldID: String) -> URL? {
        URL(string: "\(apiBase)/\(baseID)/\(recordID)/\(fieldID)/uploadAttachment")
    }

    static func encodeUploadAttachmentPayload(fileData: Data, filename: String, mimeType: String) throws -> Data {
        let payload: [String: Any] = [
            "contentType": mimeType,
            "file": fileData.base64EncodedString(),
            "filename": filename
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    static func parseUploadAttachmentResponse(from data: Data) -> String? {
        struct Response: Decodable {
            let id: String
            let fields: [String: [AirtableAttachment]]
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
        return decoded.fields.values.first?.first?.url
    }

    static func buildPatchURL(apiBase: String, baseID: String, table: String, recordID: String) -> URL? {
        let encoded = table.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? table
        return URL(string: "\(apiBase)/\(baseID)/\(encoded)/\(recordID)")
    }

    static func encodePatchPayload(fields: [String: AirtableFieldValue]) throws -> Data {
        let payload: [String: Any] = ["fields": fields.mapValues(\.jsonValue)]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    static func buildListURL(apiBase: String, baseID: String, table: String, offset: String?,
                             filterByFormula: String? = nil) -> URL? {
        let encoded = table.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? table
        var components = URLComponents(string: "\(apiBase)/\(baseID)/\(encoded)")
        var items = [URLQueryItem(name: "pageSize", value: "100")]
        if let offset { items.append(URLQueryItem(name: "offset", value: offset)) }

        if let filterByFormula, filterByFormula.isEmpty == false {
            items.append(URLQueryItem(name: "filterByFormula", value: filterByFormula))
        }
        components?.queryItems = items
        return components?.url
    }

    static func parsePage(from data: Data) throws -> AirtablePage {
        do {
            return try JSONDecoder().decode(AirtablePage.self, from: data)
        } catch {
            throw AirtableError.decodingFailed
        }
    }

    static func mapCustomers(from records: [[String: AirtableFieldValue]]) -> [Customer] {
        records.compactMap { fields in

            guard let number = fields["Kundennummer"]?.stringValue,
                  let name = fields["Name"]?.stringValue ?? fields["Firma / Name"]?.stringValue else { return nil }
            let recordID = fields["_airtableRecordID"]?.stringValue

            let clockodoID = fields["Clockodo-Kunden-ID"]?.numberValue.map { Int($0) }

            let sevDeskID = fields["sevDesk-Contact-ID"]?.stringValue
                .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            return Customer(customerNumber: number, name: name,
                            airtableRecordID: recordID, clockodoCustomerID: clockodoID,
                            sevDeskKontaktID: sevDeskID)
        }
    }

    public static func mapContacts(from records: [[String: AirtableFieldValue]]) -> [StudioContact] {
        records.compactMap { fields in
            let name = (fields["Name"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.isEmpty == false else { return nil }
            let recordID = fields["_airtableRecordID"]?.stringValue ?? name
            func nonEmpty(_ key: String) -> String? {
                let v = fields[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (v?.isEmpty == false) ? v : nil
            }
            return StudioContact(
                id: recordID, name: name,
                organisation: nonEmpty("Organisation"),
                email: nonEmpty("E-Mail"),
                telefon: nonEmpty("Telefon"),
                adresse: nonEmpty("Adresse"),
                projekt: nonEmpty("Projekt") ?? fields["Projekt"]?.firstArrayValue,
                kategorie: nonEmpty("Kategorie"),
                vorname: nonEmpty("Vorname"),
                nachname: nonEmpty("Nachname"),

                photoURL: fields["Foto"]?.firstAttachmentURL)
        }
    }

    public static func mapResidentIdentity(
        from records: [[String: AirtableFieldValue]],
        matchingEmail email: String
    ) -> ResidentIdentityHandles? {
        let needle = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.isEmpty == false else { return nil }

        func firstNonEmptyString(_ fields: [String: AirtableFieldValue], _ keys: [String]) -> String? {
            for key in keys {
                if let v = fields[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                   v.isEmpty == false {
                    return v
                }
            }
            return nil
        }

        func firstAnyString(_ fields: [String: AirtableFieldValue], _ keys: [String]) -> String? {
            for key in keys {
                if let v = fields[key]?.anyStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                   v.isEmpty == false {
                    return v
                }
            }
            return nil
        }

        let emailKeys = ["E-Mail", "Email", "E-Mail-Adresse", "E-Mail Adresse", "Mail"]

        for fields in records {
            guard let rowEmail = firstNonEmptyString(fields, emailKeys),
                  rowEmail.lowercased() == needle else { continue }

            return ResidentIdentityHandles(
                displayName: firstNonEmptyString(fields, ["Name", "Anzeigename", "Nutzer"]),
                clockodoUserID: firstAnyString(fields, ["Clockodo-User-ID", "Clockodo-Nutzer-ID", "Clockodo-ID"]),
                clockodoEntwurfsTabelle: firstNonEmptyString(fields, ["Airtable-Entwurf-Tabelle", "Entwurf-Tabelle", "Entwurfs-Tabelle"]),
                clickUpMemberID: firstAnyString(fields, ["ClickUp-Member-ID", "ClickUp-ID"]),
                airtableRecordID: fields["_airtableRecordID"]?.stringValue
            )
        }
        return nil
    }

    static func mapProjects(from records: [[String: AirtableFieldValue]]) -> [Project] {
        records.compactMap { fields in

            guard let number = fields["Projektnummer"]?.stringValue ?? fields["mykilOS-Projektnummer"]?.stringValue,
                  let title = fields["Titel"]?.stringValue ?? fields["Projektname"]?.stringValue else { return nil }

            let kindRaw = fields["Art"]?.stringValue ?? "kitchen"
            let kind = ProjectKind(rawValue: kindRaw) ?? .kitchen
            let customerNumber = fields["Kundennummer"]?.stringValue
                ?? fields["Kundennummer (Golden)"]?.stringValue
                ?? fields["Kunde"]?.firstArrayValue
                ?? ""

            let links = ProjectLinks(
                driveFolderID: fields["Drive-Ordner-ID"]?.stringValue,

                driveFolderPath: nil,

                driveFolderName: fields["Drive-Ordnername"]?.stringValue,
                clickUpListID: fields["ClickUp-Liste"]?.stringValue,
                calendarQuery: fields["Kalender-Suche"]?.stringValue,
                contactsQuery: fields["Kontakte-Suche"]?.stringValue,
                mailQuery: fields["Mail-Suche"]?.stringValue,
                sevdeskRef: fields["sevdesk-Ref"]?.stringValue ?? fields["sevDesk-Ref"]?.stringValue,
                budget: fields["Budget"]?.numberValue
            )

            let recordID = fields["_airtableRecordID"]?.stringValue

            return Project(
                projectNumber: number,
                title: title,
                kind: kind,
                customerNumber: customerNumber,
                parentProjectNumber: fields["Eltern-Projekt"]?.stringValue
                    ?? fields["Eltern-Projekt"]?.firstArrayValue,
                links: links,
                phase: fields["Phase"]?.stringValue,
                source: fields["Quelle"]?.stringValue,
                airtableRecordID: recordID
            )
        }
    }
}

public struct ResidentIdentityHandles: Equatable, Sendable {
    public var displayName: String?
    public var clockodoUserID: String?
    public var clockodoEntwurfsTabelle: String?
    public var clickUpMemberID: String?
    public var airtableRecordID: String?

    public init(
        displayName: String? = nil,
        clockodoUserID: String? = nil,
        clockodoEntwurfsTabelle: String? = nil,
        clickUpMemberID: String? = nil,
        airtableRecordID: String? = nil
    ) {
        self.displayName = displayName
        self.clockodoUserID = clockodoUserID
        self.clockodoEntwurfsTabelle = clockodoEntwurfsTabelle
        self.clickUpMemberID = clickUpMemberID
        self.airtableRecordID = airtableRecordID
    }
}

public struct AirtablePage: Decodable, Sendable {
    public let records: [[String: AirtableFieldValue]]
    public let offset: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offset = try container.decodeIfPresent(String.self, forKey: .offset)

        var rawRecords: [[String: AirtableFieldValue]] = []
        var recordsContainer = try container.nestedUnkeyedContainer(forKey: .records)
        while !recordsContainer.isAtEnd {
            let record = try recordsContainer.decode(AirtableRecord.self)
            var fields = record.fields
            fields["_airtableRecordID"] = .string(record.id)
            rawRecords.append(fields)
        }
        records = rawRecords
    }

    enum CodingKeys: String, CodingKey { case records, offset }
}

private struct AirtableRecord: Decodable {
    let id: String
    let fields: [String: AirtableFieldValue]
}

private struct CreateRecordResponse: Decodable {
    struct Created: Decodable { let id: String }
    let records: [Created]
}
