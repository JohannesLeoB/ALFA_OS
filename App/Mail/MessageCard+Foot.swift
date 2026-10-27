import AppKit
import Design
import Mail
import Shell
import SwiftUI

extension MessageCard {
    struct Foot: View {
        @Environment(\.appearance) private var appearance
        let session: AppSession
        let commands: CommandSet
        let perform: (Action) -> Void
        @State private var moreAnchor = AnchorBox()
        @State private var projectAnchor = AnchorBox()

        private var inbox: InboxState { session.inbox }

        var body: some View {
            HStack(spacing: CGFloat(Tokens.Size.headGapList)) {
                group(commands.footLeft)
                Spacer(minLength: 0)
                group(commands.footRight)
            }
            .padding(.horizontal, CGFloat(Tokens.Size.headPadRight))
            .frame(height: CGFloat(Tokens.Size.footerHeight))
            .overlay(alignment: .top) { Hairline() }
        }

        private func group(_ slots: [Slot]) -> some View {
            HStack(spacing: CGFloat(Tokens.Size.headGapStack)) {
                ForEach(slots) { slot in
                    slotView(slot).background { if slot.action == .send { sendKey(slot) } }
                }
            }
        }

        @ViewBuilder
        private func slotView(_ slot: Slot) -> some View {
            if slot.kind == .more {
                if case .message = inbox.frontRef {
                    SymbolButton(help: appearance.string("mail.action.more"), glyph: .more, hover: .fill) { openMore() }
                        .background(AnchorMarker(box: moreAnchor))
                }
            } else if slot.action == .send, slot.cost > ShellValues.commandIconCost {
                TextButton(label: appearance.text("mail.action.send"), kind: .accent, disabled: slot.off, action: { perform(.send) }) { Glyph(.send) }
            } else if let action = slot.action, action == .fromProject || action == .toProject, let glyph = action.glyph {
                SymbolButton(help: session.help(action, appearance: appearance), glyph: glyph, disabled: slot.off, hover: .fill) { openProjects() }
                    .background(AnchorMarker(box: projectAnchor))
            } else if let action = slot.action, let glyph = action.glyph {
                SymbolButton(help: session.help(action, appearance: appearance), glyph: glyph, selected: slot.accent, disabled: slot.off, hover: .fill) {
                    perform(action)
                }
                .keyboardShortcut(action.shortcut)
            }
        }

        private func sendKey(_ slot: Slot) -> some View {
            Button("") { if slot.off { inbox.announce(.recipientMissing) } else { perform(.send) } }
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }

        private func openProjects() {
            guard let rect = projectAnchor.screenRect() else { return }
            switch inbox.frontRef {
            case .draft(let id): ProjectFolderList.show(inbox, appearance: appearance, draft: id, anchor: rect)
            case .message(let id): ProjectFolderList.save(inbox, appearance: appearance, message: id, anchor: rect)
            case nil: break
            }
        }

        private func openMore() {
            guard case .message(let id) = inbox.frontRef else { return }
            let lines = MenuEngine.readingMore(starred: inbox.card(id)?.summary.flags.contains(.flagged) ?? false)
            let entries = MenuLine.entries(lines, appearance: appearance) { perform($0) }
            moreAnchor.showMenu(entries, width: Tokens.Size.menuWidthWide)
        }
    }
}
