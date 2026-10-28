import Design
import SwiftUI

struct AssistantActivity: View {
    @Environment(\.appearance) private var appearance
    let label: String
    let failed: Bool

    var body: some View {
        let dot = CGFloat(Tokens.Spacing.step4)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Circle()
                .fill(.foreground)
                .frame(width: dot, height: dot)
            Text(verbatim: label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .typeStyle(Tokens.TextStyle.caption)
        .foregroundStyle(appearance.color(failed ? \.onInverse : \.onInverseTertiary))
    }
}
