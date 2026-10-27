import Foundation

actor MessageCacheStore {
    static let defaultTimeToLive: TimeInterval = 300

    private struct Entry {
        let messages: [GmailMessage]
        let fetchedAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let timeToLive: TimeInterval
    private let clock: @Sendable () -> Date

    init(timeToLive: TimeInterval = defaultTimeToLive, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.timeToLive = timeToLive
        self.clock = clock
    }

    func cached(for query: String) -> [GmailMessage]? {
        guard let entry = entries[query], clock().timeIntervalSince(entry.fetchedAt) < timeToLive else { return nil }
        return entry.messages
    }

    func store(_ messages: [GmailMessage], for query: String) {
        entries[query] = Entry(messages: messages, fetchedAt: clock())
    }
}
