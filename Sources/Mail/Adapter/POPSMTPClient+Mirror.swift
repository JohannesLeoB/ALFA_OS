import Foundation
import Hub

extension POPSMTPClient: MirrorPort {
    var ranges: [MailboxRange] { MailboxRange.allCases }

    func startCursor() async throws -> String? { nil }

    func listIDs(folderID: String, since: Date?, limit: Int?) async throws -> MirrorListing {
        var waiting: [String] = []
        if folderID == Self.inboxID {
            let known = store.known()
            let listed = try await withSession { try await $0.identifiers() }
            try store.leftServer(Set(store.onServer().map(\.uid)).subtracting(listed.map(\.uid)))
            waiting = listed.filter { !known.contains($0.uid) }.sorted { $0.number > $1.number }.map(\.uid)
        }
        let local = store.entries(folderID).filter { entry in since.map { entry.receivedAt >= $0 } ?? true }.map(\.uid)
        var ids = waiting + local
        var older = false
        if let limit, ids.count > limit {
            ids = Array(ids.prefix(limit))
            older = true
        } else if since != nil {
            older = store.entries(folderID).count > local.count
        }
        return MirrorListing(ids: ids, hasOlder: older)
    }

    func fetchSummaries(folderID: String, ids: [String]) async throws -> [MessageSummary] {
        let missing = ids.filter { store.entry($0) == nil }
        if folderID == Self.inboxID, !missing.isEmpty {
            try await withSession { session in
                let numbers = Dictionary(try await session.identifiers().map { ($0.uid, $0.number) }) { first, _ in first }
                for uid in missing {
                    guard let number = numbers[uid] else { continue }
                    try keep(try await session.retrieve(number), uid: uid, folder: Self.inboxID, seen: false, onServer: true)
                }
            }
        }
        return ids.compactMap { store.entry($0) }.filter { !$0.hidden && $0.folder == folderID }.map { $0.summary() }
    }

    func refreshFlags(folderID: String, known: [String], cursor: String?) async throws -> FlagRefresh {
        var flags: [String: Set<Flag>] = [:]
        for id in known {
            guard let entry = store.entry(id), !entry.hidden else { continue }
            flags[id] = entry.flags
        }
        return FlagRefresh(flags: flags)
    }
}
