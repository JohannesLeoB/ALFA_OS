import ShellCore
import SwiftUI

struct Counter: View {
    @Environment(\.design) private var design
    let value: String
    var tone: KeyPath<DesignColors, RGB> = \.inkTertiary
    var ringTone: KeyPath<DesignColors, RGB>?

    var body: some View {
        let ringed = ringTone != nil
        let side = CGFloat(ringed ? Design.Size.chipHeight : Design.Spacing.step20)
        Text(verbatim: value)
            .font(.face(Design.TextSize.small))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(design.color(tone))
            .padding(.horizontal, CGFloat(ringed ? Design.Spacing.step8 : Design.Spacing.step4))
            .frame(minWidth: side, minHeight: side, maxHeight: side)
            .ring(Capsule(), ringTone.map { design.color($0) })
    }
}
