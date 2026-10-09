import Foundation

/// A failure of a tool that the platform ran, such as a web search. The answer itself came with status 200;
/// the failure is part of it, and the answer carries on.
public struct AIToolError: Sendable, Equatable {
    /// The id of the tool call that failed.
    public let toolUseID: String
    public let code: AIToolErrorCode

    public init(toolUseID: String, code: AIToolErrorCode) {
        self.toolUseID = toolUseID
        self.code = code
    }
}

/// The codes of a failed web search, as the platform names them.
public enum AIToolErrorCode: Sendable, Equatable {
    /// The rate limit of the search was reached.
    case tooManyRequests
    /// The search query is not valid.
    case invalidToolInput
    /// More searches were asked for than the limit allows.
    case maxUsesExceeded
    case queryTooLong
    /// The search request is too large, typically because of a long domain list.
    case requestTooLarge
    /// An internal error of the platform.
    case unavailable
    /// A code that this version does not know. The text is kept.
    case unknown(String)

    init(wire text: String) {
        switch text {
        case "too_many_requests": self = .tooManyRequests
        case "invalid_tool_input": self = .invalidToolInput
        case "max_uses_exceeded": self = .maxUsesExceeded
        case "query_too_long": self = .queryTooLong
        case "request_too_large": self = .requestTooLarge
        case "unavailable": self = .unavailable
        default: self = .unknown(text)
        }
    }
}

extension AIResponse {
    /// The failed searches of the answer, in the order of the answer. A search that found nothing is not a failure.
    public var toolErrors: [AIToolError] {
        blocks.compactMap { block -> AIToolError? in
            guard case let .webSearchToolResult(toolUseID, content) = block,
                  content["type"]?.string == "web_search_tool_result_error" else {
                return nil
            }
            return AIToolError(toolUseID: toolUseID, code: AIToolErrorCode(wire: content["error_code"]?.string ?? ""))
        }
    }
}
