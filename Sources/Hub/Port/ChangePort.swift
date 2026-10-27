public protocol ChangePort: Sendable {
    func changes() -> AsyncThrowingStream<Void, any Error>
}
