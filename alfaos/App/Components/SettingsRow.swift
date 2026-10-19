import ShellCore
import SwiftUI

struct SettingsRow<Trailing: View>: View {
    @Environment(\.design) private var design
    let label: Text
    var sub: Text?
    var line = true
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step12)) {
            VStack(alignment: .leading, spacing: 0) {
                label
                    .lineLimit(1)
                    .font(.face(Design.TextSize.body))
                    .foregroundStyle(design.color(\.ink))
                if let sub {
                    sub
                        .font(.face(Design.TextSize.small))
                        .monospacedDigit()
                        .foregroundStyle(design.color(\.inkTertiary))
                        .lineHeight(Design.LineHeight.small, size: Design.TextSize.small)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minWidth: CGFloat(Design.Size.composeColumnMinWidth), maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.vertical, CGFloat(Design.Spacing.step8))
        .padding(.leading, CGFloat(Design.Spacing.step16))
        .padding(.trailing, CGFloat(Design.Spacing.step8))
        .frame(minHeight: CGFloat(Design.Spacing.step44))
        .overlay(alignment: .bottom) {
            if line {
                Hairline()
                    .padding(.horizontal, CGFloat(Design.Spacing.step16))
            }
        }
    }
}

struct SettingsValue: View {
    @Environment(\.design) private var design
    let text: Text
    var tone: KeyPath<DesignColors, RGB> = \.inkSecondary

    var body: some View {
        text
            .lineLimit(1)
            .truncationMode(.tail)
            .font(.face(Design.TextSize.body))
            .foregroundStyle(design.color(tone))
            .padding(.trailing, CGFloat(Design.Size.trailingTextInset))
    }
}

struct ChoiceButton<Chevron: View>: View {
    @Environment(\.design) private var design
    let label: Text
    let action: () -> Void
    @ViewBuilder let chevron: Chevron

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                label.lineLimit(1)
                chevron
            }
            .font(.face(Design.TextSize.body))
            .foregroundStyle(design.color(\.ink))
            .padding(.leading, CGFloat(Design.Spacing.step12))
            .padding(.trailing, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Spacing.step28))
            .ring(Capsule(), design.color(\.lineStrong))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct KeyCap: View {
    @Environment(\.design) private var design
    let text: String

    var body: some View {
        let side = CGFloat(Design.Spacing.step20)
        Text(verbatim: text)
            .font(.face(Design.TextSize.small, weight: Design.Weight.medium))
            .foregroundStyle(design.color(\.inkSecondary))
            .padding(.horizontal, CGFloat(Design.Spacing.step4))
            .frame(minWidth: side, minHeight: side, maxHeight: side)
            .ring(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.field)), design.color(\.lineStrong))
    }
}
