import Foundation
import AlfaKit

public actor IMAPCommandChannel {
    private var session: IMAPSession?
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    public init() {}

    deinit {
        if let session { Task { await session.close() } }
    }

    func perform<T: Sendable>(
        retry: Bool,
        open: @Sendable () async throws -> IMAPSession,
        body: @Sendable (IMAPSession) async throws -> T
    ) async throws -> T {
        await acquire()
        defer { release() }
        do {
            return try await attempt(open: open, body: body)
        } catch where retry && Self.connectionLost(error) {
            return try await attempt(open: open, body: body)
        }
    }

    public func close() async {
        let live = session
        session = nil
        await live?.close()
    }

    private func attempt<T: Sendable>(
        open: @Sendable () async throws -> IMAPSession,
        body: @Sendable (IMAPSession) async throws -> T
    ) async throws -> T {
        let live: IMAPSession
        if let session {
            live = session
        } else {
            live = try await open()
            session = live
        }
        do {
            return try await body(live)
        } catch {
            if Self.sessionSurvives(error) == false { await close() }
            throw error
        }
    }

    private func acquire() async {
        guard busy else {
            busy = true
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty {
            busy = false
        } else {
            waiting.removeFirst().resume()
        }
    }

    private static func connectionLost(_ error: any Error) -> Bool {
        guard let failure = error as? MailTransportError else { return false }
        switch failure {
        case .connectionClosed, .connectionFailed, .timeout: return true
        case .serverRejected(let text): return text.hasPrefix("BYE")
        default: return false
        }
    }

    private static func sessionSurvives(_ error: any Error) -> Bool {
        switch error as? MailTransportError {
        case .messageNotFound, .folderNotFound: true
        default: false
        }
    }
}

public final class IMAPChannelRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: (fingerprint: Int, channel: IMAPCommandChannel)] = [:]

    public init() {}

    public func channel(for id: String, fingerprint: Int) -> IMAPCommandChannel {
        let (channel, stale) = lock.withLock { () -> (IMAPCommandChannel, IMAPCommandChannel?) in
            if let entry = entries[id], entry.fingerprint == fingerprint { return (entry.channel, nil) }
            let fresh = IMAPCommandChannel()
            let old = entries[id]?.channel
            entries[id] = (fingerprint, fresh)
            return (fresh, old)
        }
        if let stale { Task { await stale.close() } }
        return channel
    }

    public func release(_ id: String) {
        let old = lock.withLock { entries.removeValue(forKey: id)?.channel }
        if let old { Task { await old.close() } }
    }
}
