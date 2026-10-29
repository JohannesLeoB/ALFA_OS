import Foundation
import Hub

extension IMAPSMTPClient: MirrorPort {
    private static let sinceSlack: TimeInterval = 86_400
    private static let flagChunk = 1_000

    var ranges: [MailboxRange] { MailboxRange.allCases }

    func startCursor() async throws -> String? { nil }

    func listIDs(folderID: String, since: Date?, limit: Int?) async throws -> MirrorListing {
        try await withIncoming { session in
            let selection = try await session.select(folderID, readOnly: true)
            let live: [IMAPArgument] = [.raw("UNDELETED")]
            let boundary = since.map { DateEngine.formatSearchDate($0.addingTimeInterval(-Self.sinceSlack)) }
            let found = try await session.searchUIDs(live + (boundary.map { [.raw("SINCE"), .raw($0)] } ?? []))
            var wanted = found
            var older = false
            if let limit {
                older = found.count > limit
                wanted = Array(found.suffix(limit))
            } else if let boundary {
                older = try await session.countMatches(live + [.raw("BEFORE"), .raw(boundary)]) > 0
            }
            let ids = wanted.reversed().map {
                IMAPMessageReference(folder: folderID, uidValidity: selection.uidValidity, uid: $0).encoded
            }
            return MirrorListing(ids: ids, hasOlder: older, validity: String(selection.uidValidity))
        }
    }

    func fetchSummaries(folderID: String, ids: [String]) async throws -> [MessageSummary] {
        let references = try ids.map(IMAPMessageReference.decode)
        return try await withIncoming { session in
            let selection = try await session.select(folderID, readOnly: true)
            let uids = references.filter { $0.uidValidity == selection.uidValidity }.map(\.uid)
            let fetched = try await session.fetch(uids: uids, items: Self.summaryItems)
            return fetched.reversed().compactMap { entry -> MessageSummary? in
                guard let uid = entry.uid else { return nil }
                return Self.summary(entry, uid: uid, folder: folderID, uidValidity: selection.uidValidity)
            }
        }
    }

    func refreshFlags(folderID: String, known: [String], cursor: String?) async throws -> FlagRefresh {
        let references = try known.map(IMAPMessageReference.decode)
        return try await withIncoming { session in
            let selection = try await session.select(folderID, readOnly: true)
            let uids = references.filter { $0.uidValidity == selection.uidValidity }.map(\.uid)
            var flags: [String: Set<Flag>] = [:]
            for chunk in MirrorEngine.chunks(uids, size: Self.flagChunk) {
                for entry in try await session.fetch(uids: chunk, items: ["UID", "FLAGS"]) {
                    guard let uid = entry.uid else { continue }
                    let id = IMAPMessageReference(folder: folderID, uidValidity: selection.uidValidity, uid: uid).encoded
                    flags[id] = Set(entry.flags.compactMap { Flag(imapName: $0) })
                }
            }
            return FlagRefresh(flags: flags)
        }
    }
}
