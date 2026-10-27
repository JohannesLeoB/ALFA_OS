import Foundation

typealias StreamOpener = @Sendable (String, Int, TransportSecurity) async throws -> any ByteStreamPort

enum StreamRouter {
    static let timeout: TimeInterval = 60

    static func open(host: String, port: Int, security: TransportSecurity) async throws -> any ByteStreamPort {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            throw MailFailure.accountIncomplete(host)
        }
        switch security {
        case .ssl:
            return try await NetworkStream.open(host: host, port: port, tls: true)
        case .none:
            return try await NetworkStream.open(host: host, port: port, tls: false)
        case .starttls:
            #if os(macOS)
            return try await BlockingStream.open(host: host, port: port)
            #else
            throw MailFailure.tlsUnavailable
            #endif
        }
    }
}
