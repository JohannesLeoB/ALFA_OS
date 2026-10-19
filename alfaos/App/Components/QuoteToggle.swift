import ShellCore
import SwiftUI

struct QuoteToggle: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(Font(Typeface.sheet(size: Design.TextSize.small, weight: .medium)))
                .foregroundStyle(design.color(\.sheetInkSecondary))
                .padding(.horizontal, CGFloat(Design.Spacing.step8))
                .frame(height: CGFloat(Design.Size.chipHeight))
                .overlay(Capsule().strokeBorder(design.color(\.lineStrong), lineWidth: hairline))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
