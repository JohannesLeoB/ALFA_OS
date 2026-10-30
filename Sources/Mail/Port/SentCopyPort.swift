import Foundation

protocol SentCopyPort: Sendable {
    var filesSentCopy: Bool { get }
    func fileSent(_ draft: Draft, into folderID: String?) async throws
}
