import Foundation
import Observation

public struct SyncArea: Hashable, Sendable {
    public let id: String

    public init(_ id: String) {
        self.id = id
    }
}

public struct SyncAreaState: Equatable, Sendable {
    public var lastAttempt: Date?
    public var lastSuccess: Date?
    public var lastFailure: String?

    public init(lastAttempt: Date? = nil, lastSuccess: Date? = nil, lastFailure: String? = nil) {
        self.lastAttempt = lastAttempt
        self.lastSuccess = lastSuccess
        self.lastFailure = lastFailure
    }
}

@MainActor
@Observable
public final class SyncReport {
    public private(set) var states: [SyncArea: SyncAreaState] = [:]

    public init() {}

    public func state(of area: SyncArea) -> SyncAreaState {
        states[area] ?? SyncAreaState()
    }

    public func lastSuccess(of area: SyncArea) -> Date? { state(of: area).lastSuccess }

    public func lastFailure(of area: SyncArea) -> String? { state(of: area).lastFailure }

    public func lastAttempt(of area: SyncArea) -> Date? { state(of: area).lastAttempt }

    public func attempted(_ area: SyncArea, at date: Date = Date()) {
        var current = state(of: area)
        current.lastAttempt = date
        states[area] = current
    }

    public func succeeded(_ area: SyncArea, at date: Date = Date()) {
        var current = state(of: area)
        current.lastSuccess = date
        current.lastFailure = nil
        states[area] = current
    }

    public func failed(_ area: SyncArea, error: String) {
        var current = state(of: area)
        current.lastFailure = error
        states[area] = current
    }

    public func failed(_ area: SyncArea, error: any Error) {
        failed(area, error: String(describing: error))
    }
}
