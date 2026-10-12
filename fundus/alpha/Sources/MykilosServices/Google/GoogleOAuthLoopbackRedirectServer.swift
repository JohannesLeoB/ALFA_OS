import Foundation
import MykilosKit
import Network

public final class GoogleOAuthLoopbackRedirectServer: @unchecked Sendable {
    public static let shared = GoogleOAuthLoopbackRedirectServer()

    private let queue = DispatchQueue(label: "\(AppKennung.bundleID).google.oauth.loopback")
    private let stateLock = NSLock()
    private var listener: NWListener?
    private var redirectContinuation: CheckedContinuation<URL, Error>?

    public init() {}

    public func start() async throws -> String {
        let listener = try NWListener(using: .tcp, on: .any)
        let startup = LoopbackStartup()
        listener.newConnectionHandler = { [weak self] connection in
            guard let port = listener.port?.rawValue else { return }
            self?.handle(connection, port: port)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                guard let port = listener.port?.rawValue else {
                    startup.complete(.failure(GoogleOAuthError.loopbackStartupFailed))
                    return
                }
                startup.complete(.success(port))
            case .failed:
                startup.complete(.failure(GoogleOAuthError.loopbackStartupFailed))
                self?.stop()
            default:
                break
            }
        }
        setListener(listener)
        listener.start(queue: queue)

        let port: UInt16
        do {
            port = try await startup.wait(timeoutNanoseconds: 2_000_000_000)
        } catch {
            stop()
            throw error
        }
        return "http://127.0.0.1:\(port)"
    }

    public func awaitRedirect() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            stateLock.lock()
            redirectContinuation = continuation
            stateLock.unlock()
        }
    }

    public func stop() {
        stateLock.lock()
        let listener = listener
        let continuation = redirectContinuation
        self.listener = nil
        redirectContinuation = nil
        stateLock.unlock()
        listener?.cancel()
        continuation?.resume(throwing: GoogleOAuthError.loopbackCancelled)
    }

    private func setListener(_ listener: NWListener?) {
        stateLock.lock()
        self.listener = listener
        stateLock.unlock()
    }

    private func handle(_ connection: NWConnection, port: UInt16) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, _, _ in
            guard let self else { return }
            guard let data,
                  let request = String(data: data, encoding: .utf8),
                  let url = self.redirectURL(from: request, port: port) else {
                self.sendResponse("Google-Login konnte nicht gelesen werden.", status: "400 Bad Request", on: connection)
                return
            }
            self.sendResponse(
                "Google-Login wurde an ALPHA übergeben. Dieses Fenster kann geschlossen werden.",
                status: "200 OK",
                on: connection
            )
            self.stateLock.lock()
            let continuation = self.redirectContinuation
            self.redirectContinuation = nil
            self.stateLock.unlock()
            continuation?.resume(returning: url)
        }
    }

    private func redirectURL(from request: String, port: UInt16) -> URL? {
        guard let firstLine = request.split(separator: "\r\n", maxSplits: 1).first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        let target = String(parts[1])
        guard target == "/" || target.hasPrefix("/?") else { return nil }
        return URL(string: "http://127.0.0.1:\(port)\(target)")
    }

    private func sendResponse(_ body: String, status: String, on connection: NWConnection) {
        let payload = """
        HTTP/1.1 \(status)\r
        Content-Type: text/plain; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(payload.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private final class LoopbackStartup: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<UInt16, Error>?
    private var continuation: CheckedContinuation<UInt16, Error>?

    func wait(timeoutNanoseconds: UInt64) async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(with: result)
                return
            }
            self.continuation = continuation
            lock.unlock()

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                self?.complete(.failure(GoogleOAuthError.loopbackStartupFailed))
            }
        }
    }

    func complete(_ result: Result<UInt16, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
