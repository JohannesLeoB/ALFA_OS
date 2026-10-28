import Foundation

public protocol SourcePort: Sendable {
    var offersSource: Bool { get }
    func fetchSource(messageID: String) async throws -> Data
}
