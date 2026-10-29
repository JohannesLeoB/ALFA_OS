import Foundation

public struct SearchPage: Equatable, Sendable {
    var messages: [MessageSummary]
    var continuation: SearchContinuation?
    var skipped: [String]
    var total: Int?

    init(messages: [MessageSummary], continuation: SearchContinuation? = nil, skipped: [String] = [], total: Int? = nil) {
        self.messages = messages
        self.continuation = continuation
        self.skipped = skipped
        self.total = total
    }
}
