import AppKit
import Carbon.HIToolbox
import Design
import Shell
import SwiftUI

struct LockScreen: View {
    @Environment(\.appearance) private var appearance
    let lock: LockState
    let name: String
    let initials: String

    private var error: String? {
        switch lock.phase {
        case .touchIDFailed: "shell.lock.touchFailed"
        case .passwordWrong: "shell.lock.passwordWrong"
        default: nil
        }
    }

    var body: some View {
        let mark = CGFloat(Tokens.Size.lockMarkSize)
        VStack(spacing: CGFloat(Tokens.Spacing.step16)) {
            Text(verbatim: initials)
                .font(.face(Tokens.TextSize.title, weight: Tokens.Weight.medium))
                .tracking(CGFloat(Tokens.Tracking.mark * Tokens.TextSize.title))
                .lineLimit(1)
                .frame(width: mark, height: mark)
                .ring(Circle(), appearance.color(\.lineStrong))
            Text(verbatim: name)
                .typeStyle(Tokens.TextStyle.title)
                .lineLimit(1)
            if lock.phase.asksPassword { passwordActions } else { touchActions }
            if let error {
                appearance.text(error)
                    .font(.face(Tokens.TextSize.body))
                    .foregroundStyle(appearance.color(\.signal))
            }
        }
        .padding(CGFloat(Tokens.Spacing.step24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(appearance.color(\.ink))
        .background(appearance.color(\.ground))
        .contentShape(Rectangle())
        .eventMonitor(.keyDown) { sample in
            guard !sample.event.modifierFlags.contains(.command) else { return false }
            if [UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter)].contains(sample.event.keyCode) { lock.primary() }
            return true
        }
    }

    private var touchActions: some View {
        VStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            if lock.touchID {
                LockButton(label: appearance.text(lock.phase == .touchID ? "shell.lock.touchWaiting" : "shell.lock.touch"), filled: true) {
                    lock.useTouchID()
                }
            }
            LockButton(label: appearance.text("shell.lock.usePassword"), filled: false) { lock.usePassword() }
        }
    }

    private var passwordActions: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            LockButton(label: appearance.text("shell.lock.unlock"), filled: true) { lock.usePassword() }
            if lock.touchID {
                LockButton(label: appearance.text("shell.lock.useTouch"), filled: false) { lock.backToTouchID() }
            }
        }
    }
}

private struct LockButton: View {
    @Environment(\.appearance) private var appearance
    let label: Text
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.face(Tokens.TextSize.small, weight: Tokens.Weight.medium))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(appearance.color(filled ? \.onInverse : \.inkSecondary))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
                .frame(height: CGFloat(Tokens.Spacing.step28))
                .background(Capsule().fill(filled ? appearance.color(\.inverse) : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(scale: SheetValues.pressScale))
    }
}

private struct AppLockedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appLocked: Bool {
        get { self[AppLockedKey.self] }
        set { self[AppLockedKey.self] = newValue }
    }
}

extension View {
    func underLock(_ shut: Bool) -> some View {
        disabled(shut)
            .allowsHitTesting(!shut)
            .accessibilityHidden(shut)
            .environment(\.appLocked, shut)
    }
}
