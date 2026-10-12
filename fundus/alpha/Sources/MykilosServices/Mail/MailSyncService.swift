import Foundation
import MykilosKit

public actor MailSyncService {
    private let client: any MailPostbox
    private let store: MailStore
    private var isRunning = false

    public static let vollSeiten = 6
    public static let seitenGroesse = 50

    public init(client: any MailPostbox = MailPostboxes.current(), store: MailStore) {
        self.client = client
        self.store = store
    }

    public enum Result: Sendable, Equatable {
        case uebersprungen, inkrementell(neu: Int, geloescht: Int), full(Int), error(String)
    }

    @discardableResult
    public func sync() async -> Result {
        guard isRunning == false else { return .uebersprungen }
        isRunning = true
        defer { isRunning = false }

        let profile: GmailProfile
        do { profile = try await client.fetchProfile() } catch { return .error(String(describing: error)) }
        let account = profile.emailAddress

        if let start = store.historyId(account: account) {
            do {
                let delta = try await client.fetchHistory(startHistoryId: start)
                store.delete(ids: delta.deleted)
                for (id, labels) in delta.labelsSet where delta.deleted.contains(id) == false {
                    store.setLabels(labels, for: id)
                }
                let neue = await ladeEinzeln(delta.added)
                store.upsert(neue, account: account)
                store.setHistoryId(delta.historyId ?? profile.historyId, account: account)
                return .inkrementell(neu: neue.count, geloescht: delta.deleted.count)
            } catch GoogleGmailError.httpError(let code) where code == 404 {
            } catch {
                return .error(String(describing: error))
            }
        }

        var total = 0
        var token: String?
        for _ in 0..<Self.vollSeiten {
            guard let page = try? await client.listMessages(query: "-in:spam -in:trash",
                                                             maxResults: Self.seitenGroesse, pageToken: token) else { break }
            store.upsert(page.messages, account: account)
            total += page.messages.count
            token = page.nextPageToken
            if token == nil { break }
        }
        store.setHistoryId(profile.historyId, account: account)
        return .full(total)
    }

    private func ladeEinzeln(_ ids: [String]) async -> [GoogleGmailMessage] {
        var out: [GoogleGmailMessage] = []
        await withTaskGroup(of: GoogleGmailMessage?.self) { group in
            var offen = ids.makeIterator()
            var isActive = 0
            func naechste() {
                if let id = offen.next() {
                    isActive += 1
                    group.addTask { [client] in try? await client.fetchMessage(messageID: id) }
                }
            }
            for _ in 0..<6 { naechste() }
            while isActive > 0 {
                guard let m = await group.next() else { break }
                isActive -= 1
                if let m { out.append(m) }
                naechste()
            }
        }
        return out
    }
}
