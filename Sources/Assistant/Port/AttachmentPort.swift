import Foundation

public protocol AttachmentPort: Sendable {
    func save(_ url: URL) async throws -> AttachmentRef
    func sweep(keeping paths: Set<String>)
}
