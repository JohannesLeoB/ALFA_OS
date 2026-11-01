import Foundation
import Network
import Synchronization

public final class LoopbackServer: Sendable {
    static let startupTimeout: Duration = .seconds(2)
    static let readLimit = 8_192

    private struct State {
        var listener: NWListener?
        var continuation: CheckedContinuation<URL, any Error>?
        var pending: URL?
    }

    private let queue: DispatchQueue
    private let state = Mutex(State())
    private let host: String
    private let acceptedPage: String
    private let unreadablePage: String
    private let startupFailure: any Error
    private let cancelledFailure: any Error

    public init(host: String, queueLabel: String, acceptedPage: String, unreadablePage: String,
                startupFailure: any Error, cancelledFailure: any Error) {
        queue = DispatchQueue(label: queueLabel)
        self.host = host
        self.acceptedPage = acceptedPage
        self.unreadablePage = unreadablePage
        self.startupFailure = startupFailure
        self.cancelledFailure = cancelledFailure
    }

    public func start() async throws -> String {
        let listener = try NWListener(using: .tcp, on: .any)
        let startup = Startup()
        let failure = startupFailure
        listener.newConnectionHandler = { [weak self, weak listener] connection in
            guard let port = listener?.port?.rawValue else { return }
            self?.handle(connection, port: port)
        }
        listener.stateUpdateHandler = { [weak self, weak listener] newState in
            switch newState {
            case .ready:
                guard let port = listener?.port?.rawValue else {
                    startup.complete(.failure(failure))
                    return
                }
                startup.complete(.success(port))
            case .failed:
                startup.complete(.failure(failure))
                self?.stop()
            default:
                break
            }
        }
        state.withLock { $0.listener = listener }
        listener.start(queue: queue)
        let port: UInt16
        do {
            port = try await startup.wait(timeout: Self.startupTimeout, failure: failure)
        } catch {
            stop()
            throw error
        }
        return "http://\(host):\(port)"
    }

    public func awaitRedirect() async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let ready = state.withLock { state -> Result<URL, any Error>? in
                    if let pending = state.pending {
                        state.pending = nil
                        return .success(pending)
                    }
                    if Task.isCancelled { return .failure(cancelledFailure) }
                    state.continuation = continuation
                    return nil
                }
                if let ready { continuation.resume(with: ready) }
            }
        } onCancel: {
            stop()
        }
    }

    public func stop() {
        let (listener, continuation) = state.withLock { state -> (NWListener?, CheckedContinuation<URL, any Error>?) in
            let taken = (state.listener, state.continuation)
            state.listener = nil
            state.continuation = nil
            return taken
        }
        listener?.cancel()
        continuation?.resume(throwing: cancelledFailure)
    }

    private func handle(_ connection: NWConnection, port: UInt16) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.readLimit) { [weak self] data, _, _, _ in
            guard let self else { return }
            guard let data, let request = String(data: data, encoding: .utf8),
                  let url = Self.redirectURL(from: request, port: port, host: host) else {
                respond(unreadablePage, status: "400 Bad Request", on: connection)
                return
            }
            respond(acceptedPage, status: "200 OK", on: connection)
            let continuation = state.withLock { state -> CheckedContinuation<URL, any Error>? in
                guard let waiting = state.continuation else {
                    state.pending = url
                    return nil
                }
                state.continuation = nil
                return waiting
            }
            continuation?.resume(returning: url)
        }
    }

    public static func redirectURL(from request: String, port: UInt16, host: String) -> URL? {
        guard let firstLine = request.split(separator: "\r\n", maxSplits: 1).first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        let target = String(parts[1])
        guard target == "/" || target.hasPrefix("/?") else { return nil }
        return URL(string: "http://\(host):\(port)\(target)")
    }

    private func respond(_ body: String, status: String, on connection: NWConnection) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\n"
            + "Cache-Control: no-store\r\nContent-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:\r\n"
            + "Content-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data((head + body).utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
}

private final class Startup: Sendable {
    private struct State {
        var result: Result<UInt16, any Error>?
        var continuation: CheckedContinuation<UInt16, any Error>?
    }

    private let state = Mutex(State())

    func wait(timeout: Duration, failure: any Error) async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            let ready = state.withLock { state -> Result<UInt16, any Error>? in
                if let result = state.result { return result }
                state.continuation = continuation
                return nil
            }
            if let ready {
                continuation.resume(with: ready)
                return
            }
            Task {
                try? await Task.sleep(for: timeout)
                complete(.failure(failure))
            }
        }
    }

    func complete(_ result: Result<UInt16, any Error>) {
        let continuation = state.withLock { state -> CheckedContinuation<UInt16, any Error>? in
            guard state.result == nil else { return nil }
            state.result = result
            let waiting = state.continuation
            state.continuation = nil
            return waiting
        }
        continuation?.resume(with: result)
    }
}
