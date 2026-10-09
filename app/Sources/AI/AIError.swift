import Foundation

/// Every way a call to the assistant can fail. No case carries the key.
public enum AIError: Error, Sendable, Equatable {
    /// No key is stored, or the key could not be read.
    case noKey
    /// The API refused the key (401).
    case invalidKey
    /// The key may not use this model or feature (403).
    case forbidden
    /// The API refused the request (400). The message is cut to 300 characters.
    case badRequest(String)
    /// The monthly spend limit of the console is reached (429).
    case spendLimitReached
    /// The API asked to slow down (429). Carries the wait it asked for, if any.
    case rateLimited(retryAfter: TimeInterval?)
    /// The API is busy (529) or fails on its side (other 5xx).
    case overloaded(status: Int)
    /// The connection failed. The text never contains the key.
    case network(String)
    /// The answer could not be read.
    case decoding
    /// The call was cancelled.
    case cancelled
    /// An image breaks a rule (size, format, pixel size) or may not be sent.
    case imageRejected(String)
    /// The answer came, but no result could be read from it.
    case unusableAnswer(String)
    /// A tool setting breaks a rule. The request is not sent.
    case toolConfiguration(String)
    /// The request asks for web search, and the console has turned web search off for the organization (400).
    case webSearchDisabled
    /// The request is larger than the API takes (32 MB). Carries the size in bytes that was built.
    case contextTooLarge(bytes: Int)
}

extension AIError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noKey:
            "No API key is stored."
        case .invalidKey:
            "The API refused the key."
        case .forbidden:
            "The API refused this model or feature for the key."
        case let .badRequest(message):
            "The API refused the request: \(message)"
        case .spendLimitReached:
            "The monthly spend limit of the console is reached."
        case let .rateLimited(retryAfter):
            "Too many requests. Retry after: \(retryAfter.map { "\($0) s" } ?? "unknown")."
        case let .overloaded(status):
            "The API is busy (status \(status))."
        case let .network(message):
            "Connection failed: \(message)"
        case .decoding:
            "The answer could not be read."
        case .cancelled:
            "The call was cancelled."
        case let .imageRejected(reason):
            "Image rejected: \(reason)"
        case let .unusableAnswer(reason):
            "The answer has no usable result: \(reason)"
        case let .toolConfiguration(reason):
            "A tool setting breaks a rule: \(reason)"
        case .webSearchDisabled:
            "Web search is turned off for this organization in the console."
        case let .contextTooLarge(bytes):
            "The request is too large: \(bytes) bytes."
        }
    }
}
