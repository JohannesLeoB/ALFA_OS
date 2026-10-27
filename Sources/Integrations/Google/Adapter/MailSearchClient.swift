import Assistant
import Foundation

struct MailSearchClient: MailSearchPort {
    let gmail: any GmailFetchPort
    let cache: MessageCacheStore
    let account: String

    func search(query: String, limit: Int) async throws -> [MailHit] {
        let key = account + "\n" + query
        do {
            if let hit = await cache.cached(for: key), hit.count >= limit { return hit.prefix(limit).map(Self.hit) }
            let fresh = try await gmail.searchMessages(query: query, maxResults: limit)
            await cache.store(fresh, for: key)
            return fresh.map(Self.hit)
        } catch {
            throw FailureEngine.port(error)
        }
    }

    func body(messageID: String) async throws -> String {
        do {
            return try await gmail.fetchBody(messageID: messageID)
        } catch {
            throw FailureEngine.port(error)
        }
    }

    static func hit(_ message: GmailMessage) -> MailHit {
        MailHit(id: message.id, subject: message.subject, from: message.from, receivedAt: message.receivedAt,
                labels: message.labels, snippet: message.snippet, attachmentNames: message.attachments.map(\.filename))
    }
}
