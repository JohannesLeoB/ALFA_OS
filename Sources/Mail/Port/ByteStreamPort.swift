import Foundation

protocol ByteStreamPort: Sendable {
    func receive() async throws -> Data
    func receiveIdle() async throws -> Data
    func send(_ data: Data) async throws
    func upgradeToTLS() async throws
    func close()
}

extension ByteStreamPort {
    func receiveIdle() async throws -> Data {
        while true {
            do {
                return try await receive()
            } catch MailFailure.timeout {
                try Task.checkCancellation()
            }
        }
    }
}
