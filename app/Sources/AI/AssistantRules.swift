import Foundation

/// Which effort and thinking values a model family takes. The platform documents these; a value that a
/// family does not take is never sent, the plan takes the nearest value that it knows.
public enum AssistantRules {
    /// The efforts of a family, from the lowest. An unknown family gets the three common ones.
    public static func efforts(for line: ModelLine?) -> [AIEffort] {
        switch line {
        case .opus?, .fable?: AIEffort.allCases
        case .haiku?, .sonnet?, nil: [.low, .medium, .high]
        }
    }

    /// The highest effort that the family knows and that does not go above the wanted one.
    public static func effort(_ wanted: AIEffort, for line: ModelLine?) -> AIEffort {
        efforts(for: line).last { rank($0) <= rank(wanted) } ?? .low
    }

    /// Whether the thinking mode may be sent with the family and the effort.
    /// Thinking off is for Haiku and Sonnet, and for Haiku only up to high. Between tool calls is for Sonnet up to high.
    /// An unknown family only takes adaptive thinking.
    public static func allows(_ thinking: AIThinking, line: ModelLine?, effort: AIEffort) -> Bool {
        switch thinking {
        case .adaptive:
            return true
        case .disabled:
            switch line {
            case .sonnet?: return true
            case .haiku?: return rank(effort) <= rank(.high)
            default: return false
            }
        case .betweenTools:
            return line == .sonnet && rank(effort) <= rank(.high)
        }
    }

    /// The position of an effort in the order from low to max.
    static func rank(_ effort: AIEffort) -> Int {
        switch effort {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .xhigh: 3
        case .max: 4
        }
    }
}
