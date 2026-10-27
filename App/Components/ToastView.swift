import Design
import SwiftUI

struct ToastView: View {
    @Environment(\.appearance) private var appearance
    let message: Text
    var undoLabel: Text?
    var onUndo: (() -> Void)?
    let onDismiss: () -> Void

    private var stay: Double {
        onUndo == nil ? Tokens.Duration.toast : Tokens.Duration.toastUndo
    }

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step12)) {
            message.lineLimit(1)
            if let undoLabel, let onUndo {
                Button(action: onUndo) {
                    undoLabel
                        .lineLimit(1)
                        .font(.face(Tokens.TextSize.small, weight: Tokens.Weight.medium))
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
