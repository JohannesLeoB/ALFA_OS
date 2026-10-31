import Foundation
import Hub

public protocol ConversationPort: Sendable {
    func respond(_ request: ChatRequest) async throws -> Reply
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, any Error>
}

@MainActor
public protocol ChatPort: AnyObject {
    func messages(for scope: ConversationScope) -> [Message]
    func loadIfNeeded(_ scope: ConversationScope) throws
    func append(_ message: Message, to scope: ConversationScope) throws
    func remove(_ ids: Set<UUID>, from scope: ConversationScope) throws
    func clear(_ scope: ConversationScope) throws
    func attachmentPaths() throws -> Set<String>
}

public protocol HttpPort: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse)
}

public protocol KeyPort: Sendable {
    func claudeKey() async -> ClaudeKey?
}

public protocol UsagePort: Sendable {
    func book(_ usage: TokenUsage, model: String, at date: Date)
}

public protocol AttachmentPort: Sendable {
    func save(_ url: URL) async throws -> AttachmentRef
    func sweep(keeping paths: Set<String>)
}
