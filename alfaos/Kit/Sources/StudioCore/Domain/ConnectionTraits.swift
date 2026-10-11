import Foundation

public enum ConnectionDirection: String, Sendable, CaseIterable {
    case input
    case output
    case both
}

public enum ConnectionAccess: String, Sendable, CaseIterable {
    case oauth
    case key
    case token
    case none
}

public enum ConnectionSyncWay: String, Sendable, CaseIterable {
    case poll
    case push
    case hook
    case manualOnly
    case none
}
