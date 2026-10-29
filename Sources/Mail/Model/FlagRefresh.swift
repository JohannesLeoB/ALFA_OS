import Foundation

public struct FlagRefresh: Equatable, Sendable {
    public var flags: [String: Set<Flag>]
    public var cursor: String?

    public init(flags: [String: Set<Flag>], cursor: String? = nil) {
        self.flags = flags
        self.cursor = cursor
    }
}
