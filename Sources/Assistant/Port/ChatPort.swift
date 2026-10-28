import Foundation

@MainActor
public protocol ChatPort: AnyObject {
    func messages(for scope: ConversationScope) -> [Message]
    func loadIfNeeded(_ scope: ConversationScope) throws
    func append(_ message: Message, to scope: ConversationScope) throws
    func remove(_ ids: Set<UUID>, from scope: ConversationScope) throws
    func clear(_ scope: ConversationScope) throws
    func attachmentPaths() throws -> Set<String>
}
