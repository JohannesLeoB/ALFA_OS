import Assistant
import Core
import Foundation
import Hub

public struct AirtableClient: RecordFetchPort, RecordCreatePort, RecordUpdatePort, RecordDeletePort {
    static let endpoint = "https://api.airtable.com/v0"
    static let pageSize = "100"

    private let credentials: any CredentialsPort
    private let http: any HttpPort
    private let allowlist: WriteAllowlist

    public init(credentials: any CredentialsPort, http: any HttpPort, allowlist: WriteAllowlist = .standard(values: CompanyValuesStore.valueOrEmpty)) {
        self.credentials = credentials
        self.http = http
        self.allowlist = allowlist
    }

    public func fetchRecords(baseID: String, table: String, filterByFormula: String?) async throws -> [Record] {
        var records: [Record] = []
        var offset: String?
        repeat {
            var query = [URLQueryItem(name: "pageSize", value: Self.pageSize)]
            if let offset { query.append(URLQueryItem(name: "offset", value: offset)) }
            if let filterByFormula, filterByFormula.isEmpty == false {
                query.append(URLQueryItem(name: "filterByFormula", value: filterByFormula))
            }
            let data = try await send("GET", baseID: baseID, table: table, query: query)
            guard let page = try? JSONDecoder().decode(Page.self, from: data) else { throw AirtableFailure.decoding }
            records += page.records.map { Record(id: $0.id, fields: $0.fields) }
            offset = page.offset
        } while offset != nil
        return records
    }

    func createRecord(baseID: String, table: String, fields: [String: FieldValue]) async throws -> String {
        guard allowlist.allowsWrite(baseID: baseID, table: table) else {
            throw AirtableFailure.writeNotAllowed(baseID: baseID, table: table)
        }
        let body: [String: Any] = ["records": [["fields": fields.mapValues(\.jsonValue)]]]
        let data = try await send("POST", baseID: baseID, table: table, body: body)
        do {
            return try JSONDecoder().decode(Created.self, from: data).records.first?.id ?? ""
        } catch {
            Log.failure("CreatedRecordUnreadable", detail: String(describing: error))
            return ""
        }
    }

    func updateRecord(baseID: String, table: String, recordID: String, fields: [String: FieldValue]) async throws {
        guard allowlist.allowsWrite(baseID: baseID, table: table) else {
            throw AirtableFailure.writeNotAllowed(baseID: baseID, table: table)
        }
        let body: [String: Any] = ["fields": fields.mapValues(\.jsonValue)]
        _ = try await send("PATCH", baseID: baseID, table: table, recordID: recordID, body: body)
    }

    func deleteRecord(baseID: String, table: String, recordID: String) async throws {
        guard allowlist.allowsDelete(baseID: baseID, table: table) else {
            throw AirtableFailure.deleteNotAllowed(baseID: baseID, table: table)
        }
        _ = try await send("DELETE", baseID: baseID, table: table, recordID: recordID)
    }

    private func send(_ method: String, baseID: String, table: String, recordID: String? = nil,
                      query: [URLQueryItem] = [], body: [String: Any]? = nil) async throws -> Data {
        guard let held = try? credentials.load() else { throw AirtableFailure.notConnected }
        let encoded = table.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? table
        var path = "\(Self.endpoint)/\(baseID)/\(encoded)"
        if let recordID { path += "/\(recordID)" }
        guard var components = URLComponents(string: path) else { throw AirtableFailure.invalidResponse }
        if query.isEmpty == false { components.queryItems = query }
        guard let url = components.url else { throw AirtableFailure.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(held.token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await http.data(for: request)
        guard let status = response as? HTTPURLResponse else { throw AirtableFailure.invalidResponse }
        guard (200...299).contains(status.statusCode) else { throw Self.failure(status: status.statusCode, body: data) }
        return data
    }

    static func failure(status: Int, body: Data) -> AirtableFailure {
        if let text = Self.errorMessage(in: body) { return .rejected(status, text) }
        return .http(status)
    }

    private static func errorMessage(in body: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(ErrorBody.self, from: body) else { return nil }
        if let message = decoded.error?.message, message.isEmpty == false { return message }
        if let type = decoded.error?.type, type.isEmpty == false { return type }
        return nil
    }

    private struct ErrorBody: Decodable {
        struct Inner: Decodable {
            let type: String?
            let message: String?
        }

        let error: Inner?
    }

    private struct Page: Decodable {
        struct Row: Decodable {
            let id: String
            let fields: [String: FieldValue]
        }

        let records: [Row]
        let offset: String?
    }

    private struct Created: Decodable {
        struct Row: Decodable {
            let id: String
        }

        let records: [Row]
    }
}

public struct ConnectionCheck: ConnectionCheckPort {
    static let baseLengths = 15...22
    static let basePrefix = "app"

    private let http: any HttpPort
    private let table: String

    public init(http: any HttpPort, table: String = CompanyValuesStore.valueOrEmpty("airtable.table.projects")) {
        self.http = http
        self.table = table
    }

    public var integration: String { "airtable" }

    public func check(_ values: KeyValues) async throws -> String? {
        let base = values["base"]
        guard base.hasPrefix(Self.basePrefix), Self.baseLengths.contains(base.count), table.isEmpty == false else {
            throw KeyFieldFailure(field: "base")
        }
        let client = AirtableClient(
            credentials: HeldCredentials(credentials: Credentials(token: values["token"], baseID: base)),
            http: http,
            allowlist: WriteAllowlist(writable: [:]))
        do {
            _ = try await client.fetchRecords(baseID: base, table: table, filterByFormula: "FALSE()")
        } catch let failure as AirtableFailure {
            throw Self.translate(failure)
        }
        return base
    }

    static func translate(_ failure: AirtableFailure) -> any Error {
        switch failure {
        case .http(let code), .rejected(let code, _): StatusFailure(status: code)
        case .invalidResponse, .decoding, .unmapped: ShapeFailure()
        default: failure
        }
    }

    private struct HeldCredentials: CredentialsPort {
        let credentials: Credentials

        func load() throws -> Credentials? { credentials }
    }

    private struct StatusFailure: StatusErrorPort {
        let status: Int
    }

    private struct ShapeFailure: ShapeErrorPort {}
}
