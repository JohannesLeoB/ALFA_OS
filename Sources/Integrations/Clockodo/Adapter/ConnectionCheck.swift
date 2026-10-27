import Assistant
import Foundation
import Hub

public struct ConnectionCheck: ConnectionCheckPort {
    private let http: any HttpPort
    private let clock: @Sendable () -> Date

    public init(http: any HttpPort, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.http = http
        self.clock = clock
    }

    public var integration: String { "clockodo" }

    public func check(_ values: KeyValues) async throws -> String? {
        var user: Int?
        if values["user"].isEmpty == false {
            guard let number = Int(values["user"]) else { throw KeyFieldFailure(field: "user") }
            user = number
        }
        let client = ClockodoClient(
            credentials: HeldCredentials(credentials: Credentials(email: values["email"], key: values["key"])), http: http)
        do {
            try await client.check(userID: user, now: clock())
        } catch let failure as RequestFailure {
            throw Self.translate(failure)
        }
        return values["email"]
    }

    static func translate(_ failure: RequestFailure) -> any Error {
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
