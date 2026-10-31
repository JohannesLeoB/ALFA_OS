import Design
import Shell
import SwiftUI

struct ToastView: View {
    @Environment(\.appearance) private var appearance
    let message: Text
    var undoLabel: Text?
    var onUndo: (() -> Void)?
    var failed = false
    var lasts: Double?
    let onDismiss: () -> Void

    private var stay: Double {
        if failed { return Tokens.Duration.toastFail }
        if let lasts, onUndo != nil { return lasts }
        return onUndo == nil ? Tokens.Duration.toast : Tokens.Duration.toastUndo
    }

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step12)) {
            if failed {
                Glyph(.alert)
                    .padding(.leading, -CGFloat(Tokens.Spacing.step4))
            }
            message.lineLimit(1)
            if let undoLabel, let onUndo {
                Button(action: onUndo) {
                    undoLabel
                        .lineLimit(1)
                        .typeStyle(Tokens.TextStyle.control)
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .frame(height: CGFloat(Tokens.Spacing.step20))
                        .ring(Pill(), appearance.color(\.onInverse))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -CGFloat(Tokens.Spacing.step8))
            }
        }
        .font(.face(Tokens.TextSize.small))
        .foregroundStyle(appearance.color(\.onInverse))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
        .frame(height: CGFloat(Tokens.Spacing.step28))
        .background(Capsule().fill(appearance.color(\.inverse)))
        .shadowLayers(Capsule())
        .task(id: stay) {
            try? await Task.sleep(for: .seconds(stay))
            if !Task.isCancelled { onDismiss() }
        }
    }
}
