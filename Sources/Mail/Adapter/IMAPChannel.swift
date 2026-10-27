import Synchronization

actor IMAPChannel {
    private var session: IMAPClient?
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    deinit {
        if let session { Task { await session.close() } }
    }

    func perform<T: Sendable>(
        retry: Bool,
        open: @Sendable () async throws -> IMAPClient,
        body: @Sendable (IMAPClient) async throws -> T
    ) async throws -> T {
        await acquire()
        defer { release() }
        do {
            return try await attempt(open: open, body: body)
        } catch where retry && Self.connectionLost(error) {
            return try await attempt(open: open, body: body)
        }
    }

    func close() async {
        let live = session
        session = nil
        await live?.close()
    }

    private func attempt<T: Sendable>(
        open: @Sendable () async throws -> IMAPClient,
        body: @Sendable (IMAPClient) async throws -> T
    ) async throws -> T {
        let live: IMAPClient
        if let session {
            live = session
        } else {
            live = try await open()
            session = live
        }
        do {
            return try await body(live)
        } catch {
            if !Self.sessionSurvives(error) { await close() }
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
        guard let failure = error as? MailFailure else { return false }
        switch failure {
        case .connectionClosed, .connectionFailed, .timeout: return true
        case .serverRejected(let text): return text.hasPrefix("BYE")
        default: return false
        }
    }

    private static func sessionSurvives(_ error: any Error) -> Bool {
        switch error as? MailFailure {
        case .messageNotFound, .folderNotFound: true
        default: false
        }
    }
}

final class IMAPChannelRegistry: Sendable {
    private let entries = Mutex<[String: (fingerprint: String, channel: IMAPChannel)]>([:])

    func channel(for id: String, fingerprint: String) -> IMAPChannel {
        let (channel, stale) = entries.withLock { entries -> (IMAPChannel, IMAPChannel?) in
            if let entry = entries[id], entry.fingerprint == fingerprint { return (entry.channel, nil) }
            let fresh = IMAPChannel()
            let old = entries[id]?.channel
            entries[id] = (fingerprint, fresh)
            return (fresh, old)
        }
        if let stale { Task { await stale.close() } }
        return channel
    }

    func release(_ id: String) {
        let old = entries.withLock { $0.removeValue(forKey: id)?.channel }
        if let old { Task { await old.close() } }
    }
}
