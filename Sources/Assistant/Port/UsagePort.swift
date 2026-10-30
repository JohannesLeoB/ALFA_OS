import Foundation

public protocol UsagePort: Sendable {
    func book(_ usage: TokenUsage, model: String, at date: Date)
}
