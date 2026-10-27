public enum ClaudeFailure: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case rateLimited(retryAfter: Int?)
    case overloaded
    case streamInterrupted
}
