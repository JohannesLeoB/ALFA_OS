import Foundation

public protocol EverywhereSearchPort: Sendable {
    func offersEverywhere(in folders: [Folder]) -> Bool
    func searchEverywhere(query: String, pageToken: String?, maxResults: Int) async throws -> MessagePage
}
