public enum PortFailure: Error, Equatable, Sendable {
    case notConnected
    case failed(String)

    public var detail: String {
        switch self {
        case .notConnected: ""
        case .failed(let message): message
        }
    }
}

extension PortFailure {
    static func detail(of error: any Error) -> String {
        (error as? PortFailure)?.detail ?? error.localizedDescription
    }
}

enum ClaudeFailure: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case rateLimited(retryAfter: Int?)
    case overloaded
    case streamInterrupted
}
