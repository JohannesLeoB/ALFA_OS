import Foundation
import Observation

public enum LockPhase: Equatable, Sendable {
    case open
    case locked
    case touchID
    case touchIDFailed
    case password
    case passwordWrong

    public var shut: Bool { self != .open }

    public var asksPassword: Bool { self == .password || self == .passwordWrong }
}

public struct LockPause: Equatable, Sendable {
    public let onLeaving: Bool
    public let idle: TimeInterval

    static let shortest: TimeInterval = 60

    public static let immediately = LockPause(onLeaving: true, idle: shortest)
    public static let oneMinute = LockPause(onLeaving: false, idle: shortest)
    public static let fiveMinutes = LockPause(onLeaving: false, idle: 300)
    public static let fifteenMinutes = LockPause(onLeaving: false, idle: 900)
}

private let epoch = ContinuousClock.now

private func monotonicSeconds() -> TimeInterval {
    let elapsed = epoch.duration(to: .now).components
    return TimeInterval(elapsed.seconds) + TimeInterval(elapsed.attoseconds) / 1e18
}

@MainActor
@Observable
public final class LockState {
    public private(set) var phase = LockPhase.open
    public private(set) var touchID = false
    public private(set) var available: Bool
    @ObservationIgnored private var on: Bool
    @ObservationIgnored private var pause: LockPause
    @ObservationIgnored private var lastInput: TimeInterval
    @ObservationIgnored private(set) var timer: Task<Void, Never>?
    @ObservationIgnored private(set) var pending: Task<Void, Never>?
    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private var active = true
    @ObservationIgnored private var openedAt: TimeInterval?
    @ObservationIgnored private(set) var leaving: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var watchers: [@MainActor (LockPhase) -> Void] = []
    @ObservationIgnored private let center: NotificationCenter
    @ObservationIgnored private let port: any UnlockPort
    @ObservationIgnored private let reason: String
    @ObservationIgnored private let now: @MainActor () -> TimeInterval
    @ObservationIgnored private let sleep: @MainActor (TimeInterval) async throws -> Void

    static let unlockGrace: TimeInterval = 1

    public convenience init(port: any UnlockPort, on: Bool, pause: LockPause, reason: String,
                            center: NotificationCenter = .default, resigned: Notification.Name, became: Notification.Name) {
        self.init(port: port, on: on, pause: pause, reason: reason, center: center, resigned: resigned, became: became,
                  now: monotonicSeconds) { try await Task.sleep(for: .seconds($0)) }
    }

    init(port: any UnlockPort, on: Bool, pause: LockPause, reason: String, center: NotificationCenter,
         resigned: Notification.Name, became: Notification.Name, now: @escaping @MainActor () -> TimeInterval,
         sleep: @escaping @MainActor (TimeInterval) async throws -> Void) {
        self.center = center
        self.port = port
        self.on = on
        self.pause = pause
        self.reason = reason
        self.now = now
        self.sleep = sleep
        available = port.available
        lastInput = now()
        observers = [
            center.addObserver(forName: resigned, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.resign() }
            },
            center.addObserver(forName: became, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.arrive() }
            }
        ]
    }

    isolated deinit {
        for observer in observers { center.removeObserver(observer) }
    }

    private var engaged: Bool { on && available }

    public func watch(_ handler: @escaping @MainActor (LockPhase) -> Void) {
        watchers.append(handler)
    }

    public func launch() {
        if engaged { lock() } else { arm() }
    }

    public func configure(on: Bool, pause: LockPause) {
        guard on != self.on || pause != self.pause else { return }
        self.on = on
        self.pause = pause
        lastInput = now()
        arm()
    }

    public func touch() {
        guard phase == .open, !lockIfIdle() else { return }
        lastInput = now()
    }

    public func resign() {
        active = false
        guard on, phase == .open, pause.onLeaving else { return }
        if let openedAt, now() - openedAt < Self.unlockGrace {
            holdLeaving(after: Self.unlockGrace - (now() - openedAt))
        } else {
            lock()
        }
    }

    private func arrive() {
        active = true
        leaving?.cancel()
        leaving = nil
        available = port.available
        wake()
    }

    private func holdLeaving(after wait: TimeInterval) {
        leaving?.cancel()
        let sleep = sleep
        leaving = Task { [weak self] in
            do { try await sleep(max(0, wait)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.settleLeaving()
        }
    }

    private func settleLeaving() {
        leaving = nil
        guard !active, on, phase == .open, pause.onLeaving else { return }
        lock()
    }

    public func useTouchID() {
        guard touchID, phase == .locked || phase == .touchIDFailed else { return }
        enter(.touchID)
        run(.touchID)
    }

    public func usePassword() {
        guard phase.shut, !phase.asksPassword || pending == nil else { return }
        if pending != nil { port.cancel() }
        enter(.password)
        run(.password)
    }

    public func backToTouchID() {
        guard phase.asksPassword else { return }
        if pending != nil { port.cancel() }
        attempt += 1
        pending = nil
        touchID = port.touchID
        enter(.locked)
    }

    public func primary() {
        if phase.asksPassword { usePassword() } else if touchID { useTouchID() } else { usePassword() }
    }

    private func enter(_ next: LockPhase) {
        guard next != phase else { return }
        phase = next
        for watcher in watchers { watcher(next) }
    }

    private func wake() {
        if !lockIfIdle() { arm() }
    }

    private func lockIfIdle() -> Bool {
        guard engaged, phase == .open, now() - lastInput >= pause.idle else { return false }
        lock()
        return phase.shut
    }

    private func lock() {
        timer?.cancel()
        timer = nil
        leaving?.cancel()
        leaving = nil
        available = port.available
        guard available else { return }
        openedAt = nil
        touchID = port.touchID
        enter(.locked)
    }

    private func open() {
        enter(.open)
        lastInput = now()
        openedAt = lastInput
        arm()
        if !active, on, pause.onLeaving { holdLeaving(after: Self.unlockGrace) }
    }

    private func arm() {
        timer?.cancel()
        timer = nil
        guard engaged, phase == .open else { return }
        let wait = max(0, pause.idle - (now() - lastInput))
        let sleep = sleep
        timer = Task { [weak self] in
            do { try await sleep(wait) } catch { return }
            guard !Task.isCancelled else { return }
            self?.wake()
        }
    }

    private func run(_ method: UnlockMethod) {
        attempt += 1
        let current = attempt
        let port = port
        let reason = reason
        pending = Task { [weak self] in
            let outcome = await port.unlock(method, reason: reason)
            self?.settle(outcome, of: method, attempt: current)
        }
    }

    private func settle(_ outcome: UnlockOutcome, of method: UnlockMethod, attempt current: Int) {
        guard current == attempt else { return }
        pending = nil
        switch (method, outcome) {
        case (_, .granted): open()
        case (.touchID, .fallback): usePassword()
        case (.touchID, .refused):
            touchID = port.touchID
            enter(.touchIDFailed)
        case (.touchID, .cancelled), (.touchID, .interrupted): enter(.locked)
        case (.touchID, .unavailable):
            touchID = false
            enter(.locked)
        case (.password, .refused): enter(.passwordWrong)
        case (.password, .cancelled), (.password, .interrupted), (.password, .fallback): enter(.locked)
        case (.password, .unavailable):
            available = port.available
            if available { enter(.locked) } else { open() }
        }
    }
}
