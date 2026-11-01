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

public protocol EverywhereSearchPort: Sendable {
    func offersEverywhere(in folders: [Folder]) -> Bool
    func searchEverywhere(query: String, pageToken: String?, maxResults: Int) async throws -> MessagePage
}

public protocol UnseenCountPort: Sendable {
    func unseen(folderID: String) async throws -> FolderCount?
}

protocol ByteStreamPort: Sendable {
    func receive() async throws -> Data
    func receiveIdle() async throws -> Data
    func send(_ data: Data) async throws
    func upgradeToTLS() async throws
    func close()
}

extension ByteStreamPort {
    func receiveIdle() async throws -> Data {
        while true {
            do {
                return try await receive()
            } catch MailFailure.timeout {
                try Task.checkCancellation()
            }
        }
    }
}

public protocol DiscoveryPort: Sendable {
    func document(_ url: URL) async -> Data?
    func records(_ name: String, type: UInt16) async -> [Data]
}

public protocol MailTokenPort: Sendable {
    func accessToken() async throws -> String
}

public protocol ContactBookPort {
    func load() -> [Contact]
    func save(_ contacts: [Contact]) throws
}
