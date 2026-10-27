import Assistant
import Foundation
import Hub

public struct ConnectionCheck: ConnectionCheckPort {
    private let http: any HttpPort

    public init(http: any HttpPort) {
        self.http = http
    }

    public var integration: String { "clickup" }

    public func check(_ values: KeyValues) async throws -> String? {
        let client = ClickUpClient(credentials: HeldCredentials(credentials: Credentials(token: values["token"])), http: http)
        do {
            return try await client.currentUser().username
        } catch let failure as ClickUpFailure {
            throw Self.translate(failure)
        }
    }

    static func translate(_ failure: ClickUpFailure) -> any Error {
        switch failure {
        case .http(let code): StatusFailure(status: code)
        case .invalidResponse, .decoding: ShapeFailure()
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
