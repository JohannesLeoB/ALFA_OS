import ShellCore
import SwiftUI

struct Toast: View {
    @Environment(\.design) private var design
    let message: Text
    var undoLabel: Text?
    var onUndo: (() -> Void)?
    let onDismiss: () -> Void

    private var stay: Double {
        onUndo == nil ? Design.Duration.toast : Design.Duration.toastUndo
    }

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step12)) {
            message.lineLimit(1)
            if let undoLabel, let onUndo {
                Button(action: onUndo) {
                    undoLabel
                        .lineLimit(1)
                        .font(.face(Design.TextSize.small, weight: Design.Weight.medium))
                        .padding(.horizontal, CGFloat(Design.Spacing.step8))
                        .frame(height: CGFloat(Design.Spacing.step20))
                        .ring(Pill(), design.color(\.onInverse))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -CGFloat(Design.Spacing.step8))
            }
        }
        .font(.face(Design.TextSize.small))
        .foregroundStyle(design.color(\.onInverse))
        .padding(.horizontal, CGFloat(Design.Spacing.step12))
        .frame(height: CGFloat(Design.Spacing.step28))
        .background(Capsule().fill(design.color(\.inverse)))
        .floatingShadow(Capsule())
        .task(id: stay) {
            try? await Task.sleep(for: .seconds(stay))
            if !Task.isCancelled { onDismiss() }
        }
    }
}
