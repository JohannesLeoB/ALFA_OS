import Hub

public protocol KeyPort: Sendable {
    func claudeKey() async -> ClaudeKey?
}
