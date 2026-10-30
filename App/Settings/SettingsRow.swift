import AppKit
import Design
import Shell
import SwiftUI

struct SettingsRow<Trailing: View>: View {
    @Environment(\.appearance) private var appearance
    let label: Text
    var sub: Text?
    var line = true
    @ViewBuilder let trailing: Trailing

    var body: some View {
        SettingsRowLayout(gap: CGFloat(Tokens.Spacing.step12), minimum: CGFloat(Tokens.Size.fieldLabelMinWidth)) {
            VStack(alignment: .leading, spacing: 0) {
                label
                    .lineLimit(1)
                    .typeStyle(Tokens.TextStyle.body)
                    .foregroundStyle(appearance.color(\.ink))
                if let sub {
                    sub
                        .typeStyle(Tokens.TextStyle.caption)
                        .monospacedDigit()
                        .foregroundStyle(appearance.color(\.inkTertiary))
                        .lineHeight(Tokens.TextStyle.caption.lineHeight, size: Tokens.TextStyle.caption.size)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: CGFloat(Tokens.Spacing.step12)) { trailing }
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .padding(.leading, CGFloat(Tokens.Spacing.step16))
        .padding(.trailing, CGFloat(Tokens.Spacing.step8))
        .frame(minHeight: CGFloat(Tokens.Spacing.step44))
        .overlay(alignment: .bottom) {
            if line {
                Hairline()
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            }
        }
    }
}

struct SettingsRowLayout: Layout {
    let gap: CGFloat
    let minimum: CGFloat

    private struct Plan {
        let trailing: CGFloat
        let label: CGFloat
    }

    private func plan(_ width: CGFloat, _ subviews: Subviews) -> Plan {
        let ideal = subviews[1].sizeThatFits(.unspecified).width
        let least = subviews[1].sizeThatFits(ProposedViewSize(width: 0, height: nil)).width
        let share = CGFloat(SheetValues.valueMaxShare) * width
        let trailing = min(ideal, max(least, min(share, width - gap - minimum)))
        return Plan(trailing: trailing, label: max(0, width - gap - trailing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? (subviews[0].sizeThatFits(.unspecified).width + gap + subviews[1].sizeThatFits(.unspecified).width)
        let plan = plan(width, subviews)
        let label = subviews[0].sizeThatFits(ProposedViewSize(width: plan.label, height: nil))
        let trailing = subviews[1].sizeThatFits(ProposedViewSize(width: plan.trailing, height: nil))
        return CGSize(width: width, height: max(label.height, trailing.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let plan = plan(bounds.width, subviews)
        let label = subviews[0].sizeThatFits(ProposedViewSize(width: plan.label, height: nil))
        let trailing = subviews[1].sizeThatFits(ProposedViewSize(width: plan.trailing, height: nil))
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: plan.label, height: label.height))
        subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
                          proposal: ProposedViewSize(width: plan.trailing, height: trailing.height))
    }
}

struct SettingsValue: View {
    @Environment(\.appearance) private var appearance
    let text: Text
    var tone: KeyPath<Colors, ColorValue> = \.inkSecondary

    var body: some View {
        text
            .lineLimit(1)
            .truncationMode(.tail)
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(tone))
            .padding(.trailing, CGFloat(Tokens.Size.trailingTextInset))
    }
}

struct ChoiceButton: View {
    @Environment(\.appearance) private var appearance
    let label: Text
    let entries: () -> [MenuEntry]
    var anchor: AnchorBox?
    @State private var own = AnchorBox()

    var body: some View {
        Button(action: open) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                label.lineLimit(1).truncationMode(.tail)
                Glyph(.chevron, size: Tokens.Spacing.step12, stroke: SheetValues.smallIconStroke)
            }
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(\.ink))
            .padding(.leading, CGFloat(Tokens.Spacing.step12))
            .padding(.trailing, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(Tokens.Spacing.step28))
            .ring(Pill(), appearance.color(\.lineStrong))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(AnchorMarker(box: anchor ?? own))
    }

    private func open() {
        (anchor ?? own).showMenu(entries())
    }
}
