import Foundation
import Hub

public protocol MirrorPort: Sendable {
    var ranges: [MailboxRange] { get }
    var fillsPreviews: Bool { get }
    func startCursor() async throws -> String?
    func listIDs(folderID: String, since: Date?, limit: Int?) async throws -> MirrorListing
    func fetchSummaries(folderID: String, ids: [String]) async throws -> [MessageSummary]
    func refreshFlags(folderID: String, known: [String], cursor: String?) async throws -> FlagRefresh
}

public extension MirrorPort {
    var fillsPreviews: Bool { false }
}
