import Foundation

public enum LinkState: String, CaseIterable, Sendable {
    case connected
    case stored
    case connecting
    case working
    case notConnected
    case failed
    case unreadable
    case orphaned

    public var key: String { "settings.link." + rawValue }

    public init(_ state: InletState) {
        switch state {
        case .created, .locked: self = .notConnected
        case .signedIn: self = .stored
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .working: self = .working
        case .failed: self = .failed
        case .keychainUnreadable: self = .unreadable
        case .orphaned: self = .orphaned
        }
    }

    public var isBad: Bool { self == .failed || self == .unreadable }

    public var isActive: Bool { self == .connected || self == .stored || self == .working }

    public var canDisconnect: Bool { isActive || self == .failed }

    private var severity: Int {
        switch self {
        case .failed: 7
        case .unreadable: 6
        case .orphaned: 5
        case .connecting: 4
        case .working: 3
        case .stored: 2
        case .connected: 1
        case .notConnected: 0
        }
    }

    public static func combined(_ states: [LinkState]) -> LinkState {
        states.max { $0.severity < $1.severity } ?? .notConnected
    }
}

public enum LinkNote: Equatable, Sendable {
    case checked(Date)
    case unchecked
    case failed(at: Date?, lastOK: Date?)
    case signingIn
}
