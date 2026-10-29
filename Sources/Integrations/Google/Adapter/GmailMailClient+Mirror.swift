import Foundation
import Hub
import Mail

extension GmailMailClient: MirrorPort, EverywhereSearchPort {
    var ranges: [MailboxRange] { MailboxRange.allCases }

    func offersEverywhere(in folders: [Folder]) -> Bool {
        folders.contains { $0.id == Self.allMail }
    }

    func startCursor() async throws -> String? {
        try await gmail.currentHistoryID()
    }

    func searchEverywhere(query: String, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        try await listMessages(folderID: Self.allMail, query: Self.everywhereScope + " " + query, pageToken: pageToken,
                               maxResults: maxResults)
    }

    func listIDs(folderID: String, since: Date?, limit: Int?) async throws -> MirrorListing {
        let scope = try await labelQuery(folderID)
        let floor = MailboxRange.earliest
        let query = Self.join(scope, since.map { "after:\(Int(max($0, floor).timeIntervalSince1970))" })
        var ids: [String] = []
        var token: String?
        repeat {
            let wanted = min(Self.idPage, limit.map { max(1, $0 - ids.count) } ?? Self.idPage)
            let page = try await gmail.listIDs(query: query, maxResults: wanted, pageToken: token)
            ids += page.ids
            token = page.nextPageToken
        } while token != nil && (limit.map { ids.count < $0 } ?? true)
        var older = limit != nil && token != nil
        if limit == nil, let since {
            let probe = Self.join(scope, "before:\(Int(max(since, floor).timeIntervalSince1970))")
            older = try await !gmail.listIDs(query: probe, maxResults: 1, pageToken: nil).ids.isEmpty
        }
        return MirrorListing(ids: ids, hasOlder: older)
    }

    func fetchSummaries(folderID: String, ids: [String]) async throws -> [MessageSummary] {
        try await gmail.fetchMetadata(ids: ids).map(Self.summary)
    }

    func refreshFlags(folderID: String, known: [String], cursor: String?) async throws -> FlagRefresh {
        if let cursor {
            do {
                let changes = try await gmail.labelChanges(since: cursor)
                let touched = known.filter { changes.ids.contains($0) }
                return FlagRefresh(flags: try await labelFlags(touched), cursor: changes.historyID)
            } catch GoogleFailure.api(_, let fault) where fault.status == GmailClient.missingStatus {
                return try await newestFlags(known)
            }
        }
        return try await newestFlags(known)
    }

    private func newestFlags(_ known: [String]) async throws -> FlagRefresh {
        let cursor = try await gmail.currentHistoryID()
        return FlagRefresh(flags: try await labelFlags(Array(known.prefix(Self.historyFallback))), cursor: cursor)
    }

    private func labelFlags(_ ids: [String]) async throws -> [String: Set<Flag>] {
        guard !ids.isEmpty else { return [:] }
        return try await gmail.fetchLabels(ids: ids).mapValues(Self.flags)
    }
}
