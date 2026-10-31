

public enum UnlockMethod: Equatable, Sendable {
    case touchID
    case password
}

public enum UnlockOutcome: Equatable, Sendable {
    case granted
    case refused
    case cancelled
    case interrupted
    case fallback
    case unavailable
}

@MainActor
public protocol UnlockPort: AnyObject {
    var touchID: Bool { get }
    var available: Bool { get }
    func unlock(_ method: UnlockMethod, reason: String) async -> UnlockOutcome
    func cancel()
}

public protocol AttentionPort: Sendable {
    @MainActor func badge(_ count: Int)
    func prepare() async
    func announce(title: String) async
}
