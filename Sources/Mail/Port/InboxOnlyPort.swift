import Foundation

public protocol InboxOnlyPort: Sendable {
    var inboxOnly: Bool { get }
}
