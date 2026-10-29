import Foundation
import Hub

extension MailboxStore {
    private static let everywhereToken = "*"

    private static func searchable(_ folder: Folder) -> Bool {
        folder.role != .spam && folder.role != .trash
    }

    public func canSearchEverywhere(_ inlet: Inlet.ID) -> Bool {
        guard let offering = offering(inlet) else { return false }
        return offering.everywhere || folders(inlet).filter(Self.searchable).count > 1
    }

    public func search(_ inlet: Inlet.ID, folder: String, query: String, scope: SearchScope,
                       continuation: SearchContinuation?) async throws(HubFailure) -> SearchPage {
        let transport = try transport(inlet)
        switch scope {
        case .here:
            let page = try await list(transport, inlet: inlet, folder: folder, query: query,
                                      pageToken: continuation?.tokens[folder], size: MirrorEngine.pageSize)
            return SearchPage(messages: page.messages, continuation: page.nextPageToken.map { SearchContinuation(tokens: [folder: $0]) },
                              total: page.total)
        case .all:
            if offering(inlet)?.everywhere == true, let everywhere = transport as? any EverywhereSearchPort {
                let token = continuation?.tokens[Self.everywhereToken]
                let page = try await remote(inlet) {
                    try await everywhere.searchEverywhere(query: query, pageToken: token, maxResults: MirrorEngine.pageSize)
                }
                return SearchPage(messages: page.messages,
                                  continuation: page.nextPageToken.map { SearchContinuation(tokens: [Self.everywhereToken: $0]) },
                                  total: page.total)
            }
            return try await searchFolders(transport, inlet: inlet, query: query, continuation: continuation)
        }
    }

    private func searchFolders(_ transport: any MailTransportPort, inlet: Inlet.ID, query: String,
                               continuation: SearchContinuation?) async throws(HubFailure) -> SearchPage {
        let targets = folders(inlet).filter { Self.searchable($0) && (continuation?.tokens[$0.id] != nil || continuation == nil) }
        var found: [MessageSummary] = []
        var tokens: [String: String] = [:]
        var skipped: [String] = []
        var totals: [Int] = []
        var failure: HubFailure?
        for target in targets {
            let token = continuation?.tokens[target.id].flatMap { $0.isEmpty ? nil : $0 }
            do {
                let page = try await list(transport, inlet: inlet, folder: target.id, query: query, pageToken: token,
                                          size: MirrorEngine.pageSize)
                found += page.messages
                if let next = page.nextPageToken { tokens[target.id] = next }
                if let total = page.total { totals.append(total) }
            } catch {
                failure = error
                skipped.append(target.id)
                tokens[target.id] = token ?? ""
            }
        }
        if let failure, skipped.count == targets.count { throw failure }
        var seen = Set<String>()
        let unique = found.filter { seen.insert($0.id).inserted }
        let total = skipped.isEmpty && totals.count == targets.count ? totals.reduce(0, +) : nil
        return SearchPage(messages: MirrorEngine.sorted(unique), continuation: tokens.isEmpty ? nil : SearchContinuation(tokens: tokens),
                          skipped: skipped, total: continuation == nil ? total : nil)
    }
}
