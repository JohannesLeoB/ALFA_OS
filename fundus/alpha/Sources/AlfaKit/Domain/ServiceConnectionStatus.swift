import Foundation

public enum ClickUpConnectionStatus: Equatable, Sendable {
    case disconnected
    case connected
    case error(String)
}

public enum ClockodoConnectionStatus: Equatable, Sendable {
    case disconnected
    case connected
    case error(String)
}

public enum SevdeskConnectionStatus: Equatable, Sendable {
    case disconnected
    case connected
    case error(String)
}

public enum GoogleConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

public protocol AuthStatusValue: Sendable {
    var isConnected: Bool { get }
    var isConnecting: Bool { get }
    var isWorking: Bool { get }
    var failure: String? { get }
}

public extension AuthStatusValue {
    var isConnecting: Bool { false }
    var isWorking: Bool { false }

    var connectionState: ConnectionState {
        if let failure { return .failed(failure) }
        if isConnecting { return .connecting }
        if isWorking { return .working }
        return isConnected ? .connected : .notConnected
    }

    var countsAsConnected: Bool { isConnected || isWorking }
}

extension ClickUpConnectionStatus: AuthStatusValue {
    public var isConnected: Bool { self == .connected }
    public var failure: String? { if case .error(let message) = self { message } else { nil } }
}

extension ClockodoConnectionStatus: AuthStatusValue {
    public var isConnected: Bool { self == .connected }
    public var failure: String? { if case .error(let message) = self { message } else { nil } }
}

extension SevdeskConnectionStatus: AuthStatusValue {
    public var isConnected: Bool { self == .connected }
    public var failure: String? { if case .error(let message) = self { message } else { nil } }
}

extension GoogleConnectionStatus: AuthStatusValue {
    public var isConnected: Bool { self == .connected }
    public var isConnecting: Bool { self == .connecting }
    public var failure: String? { if case .error(let message) = self { message } else { nil } }
}
