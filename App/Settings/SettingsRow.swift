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
    @State private var width: CGFloat?

    private var room: CGFloat? {
        width.map { max(0, $0 - CGFloat(Tokens.Spacing.step16 + Tokens.Spacing.step16 - Tokens.Size.confirmPillOffset)) }
    }

    var body: some View {
        SettingsRowLayout(gap: CGFloat(Tokens.Spacing.step12), minimum: CGFloat(Tokens.Size.fieldLabelMinWidth)) {
            VStack(alignment: .leading, spacing: 0) {
                label
                    .lineLimit(1)
                    .help(label)
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
                .environment(\.pillRoom, room)
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .padding(.leading, CGFloat(Tokens.Spacing.step16))
        .padding(.trailing, CGFloat(Tokens.Spacing.step16))
        .frame(minHeight: CGFloat(Tokens.Spacing.step44))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
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
        let share = CGFloat(Tokens.Ratio.fieldValueMax) * width
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
    var compact = false

    var body: some View {
        text
            .lineLimit(1)
            .truncationMode(.tail)
            .help(text)
            .font(.face(compact ? SheetValues.compactValueSize : Tokens.TextSize.body))
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
        .help(label)
        .background(AnchorMarker(box: anchor ?? own))
    }

    private func open() {
        (anchor ?? own).showMenu(entries())
    }
}

struct ValueField: View {
    @Environment(\.appearance) private var appearance
    @Binding var text: String
    let labelKey: String
    var prompt: Text?
    var onEnd: (() -> Void)?
    @FocusState private var focused: Bool

    var body: some View {
        TextField(text: $text, prompt: prompt?.foregroundStyle(appearance.color(\.inkTertiary))) { appearance.text(labelKey) }
            .textFieldStyle(.plain)
            .focused($focused)
            .onSubmit { onEnd?() }
            .onChange(of: focused) { _, now in if !now { onEnd?() } }
            .multilineTextAlignment(.trailing)
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(\.ink))
            .autocorrectionDisabled()
            .padding(.trailing, CGFloat(Tokens.Size.trailingTextInset))
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(Tokens.Spacing.step28))
    }
}

struct BlockHead: View {
    @Environment(\.appearance) private var appearance
    let key: String

    var body: some View {
        appearance.text(key)
            .font(.face(Tokens.TextSize.small))
            .foregroundStyle(appearance.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step36), alignment: .bottomLeading)
    }
}

struct BlockNote: View {
    @Environment(\.appearance) private var appearance
    let text: Text

    var body: some View {
        text
            .typeStyle(Tokens.TextStyle.caption)
            .foregroundStyle(appearance.color(\.inkTertiary))
            .lineHeight(Tokens.TextStyle.caption.lineHeight, size: Tokens.TextStyle.caption.size)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.vertical, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RowPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: CGFloat(Tokens.Size.confirmPillWidth), alignment: .trailing)
            .padding(.trailing, -CGFloat(Tokens.Size.confirmPillOffset))
    }
}

extension View {
    func rowPill() -> some View {
        modifier(RowPill())
    }
}
