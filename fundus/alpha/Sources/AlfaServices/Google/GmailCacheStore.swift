import Foundation

public struct GmailCacheEntry: Sendable {
    public let messages: [GoogleGmailMessage]
    public let fetchedAt: Date

    public func isValid(ttl: TimeInterval = 300) -> Bool {
        Date().timeIntervalSince(fetchedAt) < ttl
    }
}

public actor GmailCacheStore {
    private var entries: [String: GmailCacheEntry] = [:]
    public let ttl: TimeInterval

    public init(ttl: TimeInterval = 300) {
        self.ttl = ttl
    }

    public func cached(for query: String) -> [GoogleGmailMessage]? {
        guard let entry = entries[query], entry.isValid(ttl: ttl) else { return nil }
        return entry.messages
    }

    public func store(_ messages: [GoogleGmailMessage], for query: String) {
        entries[query] = GmailCacheEntry(messages: messages, fetchedAt: Date())
    }

    public func invalidate(query: String? = nil) {
        if let query {
            entries.removeValue(forKey: query)
        } else {
            entries.removeAll()
        }
    }

    public var validEntryCount: Int {
        entries.values.filter { $0.isValid(ttl: ttl) }.count
    }
}
