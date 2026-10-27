import Foundation
import Network
import Synchronization

final class NetworkStream: ByteStreamPort, @unchecked Sendable {
    private static let chunk = 65536

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "mail.network.stream")

    private init(connection: NWConnection) {
        self.connection = connection
    }

    static func open(host: String, port: Int, tls: Bool) async throws -> NetworkStream {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw MailFailure.accountIncomplete(host)
        }
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = Int(StreamRouter.timeout)
        let parameters = NWParameters(tls: tls ? NWProtocolTLS.Options() : nil, tcp: tcp)
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: parameters)
        let stream = NetworkStream(connection: connection)
        try await stream.start()
        return stream
    }

    private func start() async throws {
        let connection = self.connection
        let queue = self.queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let latch = ResumeLatch()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if latch.take() { continuation.resume() }
                case .failed(let error), .waiting(let error):
                    if latch.take() {
                        continuation.resume(throwing: MailFailure.connectionFailed(String(describing: error)))
                    }
                    connection.cancel()
                case .cancelled:
                    if latch.take() { continuation.resume(throwing: MailFailure.connectionClosed) }
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + StreamRouter.timeout) {
                if latch.take() {
                    continuation.resume(throwing: MailFailure.timeout)
                    connection.cancel()
                }
            }
        }
    }

    func receive() async throws -> Data {
        try await read(bounded: true)
    }

    func receiveIdle() async throws -> Data {
        try await read(bounded: false)
    }

    private func read(bounded: Bool) async throws -> Data {
        let connection = self.connection
        let queue = self.queue
        do {
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    let latch = ResumeLatch()
                    if bounded {
                        queue.asyncAfter(deadline: .now() + StreamRouter.timeout) {
                            if latch.take() {
                                continuation.resume(throwing: MailFailure.timeout)
                                connection.cancel()
                            }
                        }
                    }
                    connection.receive(minimumIncompleteLength: 1, maximumLength: Self.chunk) { data, _, isComplete, error in
                        guard latch.take() else { return }
                        if let error {
                            continuation.resume(throwing: MailFailure.connectionFailed(String(describing: error)))
                        } else if let data, !data.isEmpty {
                            continuation.resume(returning: data)
                        } else if isComplete {
                            continuation.resume(throwing: MailFailure.connectionClosed)
                        } else {
                            continuation.resume(returning: Data())
                        }
                    }
                }
            } onCancel: {
                connection.cancel()
            }
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
    }

    func send(_ data: Data) async throws {
        let connection = self.connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: MailFailure.connectionFailed(String(describing: error)))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func upgradeToTLS() async throws {
        throw MailFailure.tlsUnavailable
    }

    func close() {
        connection.cancel()
    }
}

final class ResumeLatch: Sendable {
    private let taken = Mutex(false)

    func take() -> Bool {
        taken.withLock { value in
            if value { return false }
            value = true
            return true
        }
    }
}
