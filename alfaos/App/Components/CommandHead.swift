import AppKit
import ShellCore
import SwiftUI

struct CommandHead<Action: Equatable & Sendable, Pill: View>: View {
    @Environment(\.design) private var design
    let plan: CommandPlan<Action>
    let glyph: (Action) -> Icon?
    let help: (Action) -> String
    var shortcut: (Action) -> KeyboardShortcut? = { _ in nil }
    let perform: (Action) -> Void
    let more: ([Action]) -> [MenuEntry]
    @ViewBuilder let pill: () -> Pill
    @State private var moreAnchor = AnchorBox()

    var body: some View {
        HStack(spacing: CGFloat(Lane.trailing.headGap)) {
            group(plan.main)
            Spacer(minLength: 0)
            group(plan.end)
        }
        .padding(.leading, CGFloat(Lane.trailing.headLeading))
        .padding(.trailing, CGFloat(Lane.trailing.headTrailing))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .frame(maxWidth: .infinity)
        .background(design.color(\.lane))
    }

    private func group(_ slots: [CommandSlot<Action>]) -> some View {
        HStack(spacing: CGFloat(Lane.trailing.headGap)) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                view(slot)
            }
        }
    }

    @ViewBuilder
    private func view(_ slot: CommandSlot<Action>) -> some View {
        switch slot.kind {
        case .separator:
            Rectangle().fill(design.color(\.line)).frame(width: CGFloat(Design.Size.hairline), height: CGFloat(Design.Spacing.step20))
                .padding(.horizontal, CGFloat(Design.Spacing.step4))
        case .pill:
            pill()
        case .more:
            SymbolButton(help: words("mail.action.more"), glyph: .more, tone: \.inkSecondary, hover: .fill) { openMore() }
                .background(AnchorProbe(box: moreAnchor))
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
        guard let rect = moreAnchor.screenRect() else { return }
        let entries = more(plan.overflow.compactMap(\.action))
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthWide, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}
