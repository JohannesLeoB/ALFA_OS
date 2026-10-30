import Foundation

public struct UsageTotals: Equatable, Sendable {
    public var input: Int
    public var output: Int
    public var calls: Int
    public var since: Date?

    public init(input: Int = 0, output: Int = 0, calls: Int = 0, since: Date? = nil) {
        self.input = input
        self.output = output
        self.calls = calls
        self.since = since
    }
}

public enum UsagePrice: String, CaseIterable, Sendable {
    case input
    case output
}
