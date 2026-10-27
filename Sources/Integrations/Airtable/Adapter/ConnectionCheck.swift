import Assistant
import Core
import Foundation
import Hub

public struct ConnectionCheck: ConnectionCheckPort {
    static let baseLengths = 15...22
    static let basePrefix = "app"

    private let http: any HttpPort
    private let table: String

    public init(http: any HttpPort, table: String = CompanyValues.valueOrEmpty("airtable.table.projects")) {
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
