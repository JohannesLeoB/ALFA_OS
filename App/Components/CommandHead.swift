import Design
import Shell
import SwiftUI

struct CommandHead<Action: Equatable & Sendable, Slot: View>: View {
    @Environment(\.appearance) private var appearance
    let plan: CommandPlan<Action>
    let moreHelp: String
    let glyph: (Action) -> Icon?
    let help: (Action) -> String
    var shortcut: (Action) -> KeyboardShortcut? = { _ in nil }
    let perform: (Action) -> Void
    let more: ([Action]) -> [MenuEntry]
    @ViewBuilder let pill: () -> Slot
    @State private var moreAnchor = AnchorBox()

    var body: some View {
        HStack(spacing: CGFloat(LaneKind.trailing.headGap)) {
            group(plan.main)
            Spacer(minLength: 0)
            group(plan.end)
        }
        .padding(.leading, CGFloat(LaneKind.trailing.headLeading))
        .padding(.trailing, CGFloat(LaneKind.trailing.headTrailing))
        .frame(height: CGFloat(Tokens.Size.headerHeight))
        .frame(maxWidth: .infinity)
        .background(appearance.color(\.lane))
    }

    private func group(_ slots: [CommandSlot<Action>]) -> some View {
        HStack(spacing: CGFloat(LaneKind.trailing.headGap)) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                view(slot)
            }
        }
    }

    @ViewBuilder
    private func view(_ slot: CommandSlot<Action>) -> some View {
        switch slot.kind {
        case .separator:
            Rectangle().fill(appearance.color(\.line)).frame(width: CGFloat(Tokens.Size.hairline), height: CGFloat(Tokens.Spacing.step20))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step4))
        case .pill:
            pill()
        case .more:
            SymbolButton(help: moreHelp, glyph: .more, tone: \.inkSecondary, hover: .fill) { openMore() }
                .background(AnchorMarker(box: moreAnchor))
        case .button:
            if let action = slot.action, let icon = glyph(action) {
                SymbolButton(help: help(action), glyph: icon, selected: slot.accent, disabled: slot.off,
                             tone: slot.signal ? \.signal : \.inkSecondary, hoverTone: slot.signal ? \.signal : \.ink, hover: .fill) {
                    perform(action)
                }
                .keyboardShortcut(shortcut(action))
            }
        }
    }

    private func openMore() {
        moreAnchor.showMenu(more(plan.overflow.compactMap(\.action)))
    }
}
