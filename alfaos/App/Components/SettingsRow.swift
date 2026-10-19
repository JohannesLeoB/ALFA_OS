import ShellCore
import SwiftUI

struct SettingsRow<Trailing: View>: View {
    @Environment(\.design) private var design
    let label: Text
    var sub: Text?
    var line = true
    @ViewBuilder let trailing: Trailing

    var body: some View {
        SettingsRowLayout(gap: CGFloat(Design.Spacing.step12), stackedGap: CGFloat(Design.Spacing.step8),
                          minimum: CGFloat(Design.Size.composeColumnMinWidth)) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: CGFloat(Design.Spacing.step8)) { trailing }
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

struct SettingsRowLayout: Layout {
    let gap: CGFloat
    let stackedGap: CGFloat
    let minimum: CGFloat

    private struct Plan {
        let stacked: Bool
        let trailing: CGFloat
        let label: CGFloat
    }

    private func plan(_ width: CGFloat, _ subviews: Subviews) -> Plan {
        let ideal = subviews[1].sizeThatFits(.unspecified).width
        let least = subviews[1].sizeThatFits(ProposedViewSize(width: 0, height: nil)).width
        let room = width - gap - minimum
        if least > room { return Plan(stacked: true, trailing: min(ideal, width), label: width) }
        let share = CGFloat(SheetValues.valueMaxShare) * width
        let trailing = min(ideal, max(least, min(room, share)))
        return Plan(stacked: false, trailing: trailing, label: width - gap - trailing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? (subviews[0].sizeThatFits(.unspecified).width + gap + subviews[1].sizeThatFits(.unspecified).width)
        let plan = plan(width, subviews)
        let label = subviews[0].sizeThatFits(ProposedViewSize(width: plan.label, height: nil))
        let trailing = subviews[1].sizeThatFits(ProposedViewSize(width: plan.trailing, height: nil))
        return CGSize(width: width, height: plan.stacked ? label.height + stackedGap + trailing.height : max(label.height, trailing.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let plan = plan(bounds.width, subviews)
        let label = subviews[0].sizeThatFits(ProposedViewSize(width: plan.label, height: nil))
        let trailing = subviews[1].sizeThatFits(ProposedViewSize(width: plan.trailing, height: nil))
        if plan.stacked {
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: plan.label, height: label.height))
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + label.height + stackedGap), anchor: .topLeading,
                              proposal: ProposedViewSize(width: plan.trailing, height: trailing.height))
        } else {
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                              proposal: ProposedViewSize(width: plan.label, height: label.height))
            subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
                              proposal: ProposedViewSize(width: plan.trailing, height: trailing.height))
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

struct ChoiceButton: View {
    @Environment(\.design) private var design
    let label: Text
    var width = Design.Size.menuWidthNarrow
    let entries: () -> [MenuEntry]
    @State private var anchor = AnchorBox()

    var body: some View {
        Button(action: open) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                label.lineLimit(1)
                Glyph(.chevron, size: Design.Spacing.step12, stroke: SheetValues.smallIconStroke)
            }
            .fixedSize(horizontal: true, vertical: false)
            .font(.face(Design.TextSize.body))
            .foregroundStyle(design.color(\.ink))
            .padding(.leading, CGFloat(Design.Spacing.step12))
            .padding(.trailing, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Spacing.step28))
            .ring(Pill(), design.color(\.lineStrong))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(AnchorProbe(box: anchor))
    }

    private func open() {
        guard let rect = anchor.screenRect() else { return }
        MenuPanel.shared.show(entries: entries(), width: width, anchor: .rect(rect), window: NSApp.keyWindow)
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
