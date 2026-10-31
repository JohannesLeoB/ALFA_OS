import Foundation

public enum LinkState: String, CaseIterable, Sendable {
    case connected
    case connecting
    case working
    case notConnected
    case failed
    case unreadable

    public var key: String { "settings.link." + rawValue }

    public init(_ state: InletState) {
        switch state {
        case .created: self = .notConnected
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .working: self = .working
        case .failed: self = .failed
        case .keychainUnreadable: self = .unreadable
        }
    }

    public var isBad: Bool { self == .failed || self == .unreadable }

    var isActive: Bool { self == .connected || self == .working }

    public var canDisconnect: Bool { isActive || self == .failed }

    private var severity: Int {
        switch self {
        case .failed: 7
        case .unreadable: 6
        case .connecting: 4
        case .working: 3
        case .connected: 1
        case .notConnected: 0
        }
    }

    static func combined(_ states: [LinkState]) -> LinkState {
        states.max { $0.severity < $1.severity } ?? .notConnected
    }
}

public enum LinkNote: Equatable, Sendable {
    case checked(Date)
    case failed(at: Date?, lastOK: Date?)
    case signingIn
    case working(areaKey: String, done: Int, total: Int)
}
