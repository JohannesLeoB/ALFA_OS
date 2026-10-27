import Assistant
import Foundation
import Hub

public struct ConnectionCheck: ConnectionCheckPort {
    private let http: any HttpPort

    public init(http: any HttpPort) {
        self.http = http
    }

    public var integration: String { "sevdesk" }

    public func check(_ values: KeyValues) async throws -> String? {
        let client = SevdeskClient(credentials: HeldCredentials(credentials: Credentials(token: values["token"])), http: http)
        do {
            try await client.check()
            return nil
        } catch let failure as SevdeskFailure {
            throw Self.translate(failure)
        }
    }

    static func translate(_ failure: SevdeskFailure) -> any Error {
        switch failure {
        case .http(let code): StatusFailure(status: code)
        case .invalidResponse, .decoding: ShapeFailure()
        case .notConnected: failure
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
