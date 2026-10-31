import AppKit
import Foundation
import LocalAuthentication
import UserNotifications

@MainActor
public final class UnlockClient: UnlockPort {
    private var context: LAContext?

    public init() {}

    public var touchID: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    public var available: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    public func unlock(_ method: UnlockMethod, reason: String) async -> UnlockOutcome {
        context?.invalidate()
        let current = LAContext()
        context = current
        let policy: LAPolicy = method == .touchID ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        let outcome = await withCheckedContinuation { (continuation: CheckedContinuation<UnlockOutcome, Never>) in
            Self.evaluate(current, policy: policy, reason: reason, continuation: continuation)
        }
        if context === current { context = nil }
        return outcome
    }

    public func cancel() {
        context?.invalidate()
        context = nil
    }

    nonisolated private static func evaluate(_ context: LAContext, policy: LAPolicy, reason: String,
                                             continuation: CheckedContinuation<UnlockOutcome, Never>) {
        context.evaluatePolicy(policy, localizedReason: reason) { granted, error in
            continuation.resume(returning: outcome(granted: granted, error: error))
        }
    }

    nonisolated private static func outcome(granted: Bool, error: (any Error)?) -> UnlockOutcome {
        if granted { return .granted }
        guard let code = (error as? LAError)?.code else { return .refused }
        switch code {
        case .userFallback: return .fallback
        case .userCancel: return .cancelled
        case .systemCancel, .appCancel, .notInteractive: return .interrupted
        case .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout, .passcodeNotSet: return .unavailable
        default: return .refused
        }
    }
}

public struct AttentionClient: AttentionPort {
    public init() {}

    @MainActor
    public func badge(_ count: Int) {
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
    }

    public func prepare() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    public func announce(title: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
