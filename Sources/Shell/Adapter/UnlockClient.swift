import Foundation
import LocalAuthentication

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
