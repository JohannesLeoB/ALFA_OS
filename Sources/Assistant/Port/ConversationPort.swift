public protocol ConversationPort: Sendable {
    func respond(_ request: ChatRequest) async throws -> Reply
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, any Error>
}
