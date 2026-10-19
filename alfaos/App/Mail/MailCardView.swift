import AppKit
import Mail
import ShellCore
import SwiftUI

struct StackCardView: View {
    let model: MailModel
    let ref: CardRef
    let depth: Int
    let first: Bool
    let commands: MailCommands
    @Binding var discarding: UUID?
    @Binding var formatOn: Bool

    var body: some View {
        CardFace(depth: depth, first: first, bring: { model.bring(ref) }) { ink in
            CardHead(model: model, ref: ref, front: depth == 0, ink: ink)
        } content: {
            content
            if commands.hasFooter {
                CardFoot(model: model, commands: commands, formatOn: $formatOn)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch ref {
        case .message(let id):
            if let card = model.card(id) { ReadingView(model: model, card: card) }
        case .draft(let id):
            if let card = model.draft(id) {
                ComposeView(model: model, card: card, formatOn: formatOn)
            }
        }
    }
}

struct CardHead: View {
    let model: MailModel
    let ref: CardRef
    let front: Bool
    let ink: Color
    @State private var titleAnchor = AnchorBox()

    var body: some View {
        HStack(spacing: CGFloat(Design.Size.headGapList)) {
            markView
                .padding(.trailing, CGFloat(Design.Spacing.step12))
            titleView
            metaView
            if case .message(let id) = ref, model.card(id)?.pinned == false {
                CardHeadButton(help: words("mail.card.pin.tip"), glyph: .pin, ink: ink) { model.pin(id) }
            }
            CardHeadButton(help: words("card.close"), glyph: .close, ink: ink, fills: false) { close() }
        }
        .padding(.horizontal, CGFloat(Design.Size.headPadRight))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .overlay(alignment: .bottom) {
            if front { Hairline() }
        }
    }

    private func close() {
        switch ref {
        case .message(let id): model.close(id)
        case .draft(let id): Task { await model.closeDraft(id) }
        }
    }

    private var party: (name: String, address: String)? {
        guard case .message(let id) = ref, let card = model.card(id) else { return nil }
        return model.party(card.summary)
    }

    private var draftPeople: [MailPerson] {
        guard case .draft(let id) = ref, let card = model.draft(id) else { return [] }
        return card.people(.to)
    }

    private var markView: some View {
        let side = CGFloat(Design.Size.symbolSize)
        return Group {
            if let party {
                let initials = MailNames.initials(party.name)
                if initials.isEmpty { Glyph(.person) } else { Text(verbatim: initials) }
            } else {
                Glyph(.compose)
            }
        }
        .designText(size: Design.TextSize.small, weight: .medium)
        .lineLimit(1)
        .frame(width: side, height: side)
        .overlay(Circle().strokeBorder(ink.opacity(Design.Opacity.ringOnMark), lineWidth: CGFloat(Design.Size.hairline)))
    }

    @ViewBuilder
    private var titleView: some View {
        if case .message(let id) = ref, let party {
            let name = party.name.isEmpty ? MailNames.middle(party.address, limit: SheetValues.cardTitleLimit) : party.name
            Text(verbatim: name)
                .designText(size: Design.TextSize.body, weight: .medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(Text(verbatim: front ? party.address : ""))
                .background(AnchorProbe(box: titleAnchor))
                .onTapGesture { if front { personMenu(id: id, party: party) } }
        } else if case .draft = ref {
            Group {
                if let first = draftPeople.first {
                    line("mail.row.to", first.label)
                } else {
                    word("mail.row.newMessage")
                }
            }
            .designText(size: Design.TextSize.body, weight: .medium)
            .lineLimit(1)
            .truncationMode(.tail)
        }
    }

    private func personMenu(id: String, party: (name: String, address: String)) {
        guard let rect = titleAnchor.screenRect() else { return }
        let actions = MailDo(model: model)
        let entries = MailMenuLine.entries(MailMenus.person(address: party.address)) { action in
            actions.person(action, name: party.name, address: party.address, message: id)
        }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthWide, anchor: .rect(rect), window: NSApp.keyWindow)
    }

    @ViewBuilder
    private var metaView: some View {
        let opacity = SheetValues.metaOpacity
        if case .message(let id) = ref, let card = model.card(id), let party {
            if front {
                Text(verbatim: party.name.isEmpty ? "" : MailNames.middle(party.address, limit: SheetValues.cardAddressLimit))
                    .designText(size: Design.TextSize.small)
                    .opacity(opacity)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
                MailDate(label: MailDateLabel.of(card.summary.receivedAt, now: model.now), tone: \.ink)
                    .opacity(opacity)
            }
        } else if case .draft(let id) = ref, let card = model.draft(id) {
            let more = max(0, draftPeople.count - 1)
            if !front && more > 0 {
                Spacer(minLength: 0)
                line("mail.card.more", MailNames.number(more)).designText(size: Design.TextSize.small).opacity(opacity).lineLimit(1)
            } else {
                draftMeta(card)
                    .designText(size: Design.TextSize.small)
                    .opacity(opacity)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func draftMeta(_ card: MailDraftCard) -> Text {
        guard front else { return Text(verbatim: card.draft.subject) }
        switch card.state {
        case .saved: return word("mail.draft.saved")
        case .sending, .queuedInOutbox: return word("mail.draft.sending")
        case .sendFailed: return word("mail.draft.sendFailed")
        default: return Text(verbatim: card.draft.subject)
        }
    }
}

struct CardFoot: View {
    @Environment(\.mailLaneLink) private var link
    let model: MailModel
    let commands: MailCommands
    @Binding var formatOn: Bool
    @State private var moreAnchor = AnchorBox()
    @State private var discarding: UUID?

    private var run: SlotRun { SlotRun(model: model, link: link, discarding: $discarding, formatOn: $formatOn) }

    var body: some View {
        HStack(spacing: CGFloat(Design.Size.headGapList)) {
            group(commands.footLeft)
            Spacer(minLength: 0)
            group(commands.footRight)
        }
        .padding(.horizontal, CGFloat(Design.Size.headPadRight))
        .frame(height: CGFloat(Design.Size.footerHeight))
        .overlay(alignment: .top) { Hairline() }
    }

    private func group(_ slots: [MailSlot]) -> some View {
        HStack(spacing: CGFloat(Design.Size.headGapStack)) {
            ForEach(slots) { slot in
                if slot.kind == .more {
                    SymbolButton(help: words("mail.action.more"), glyph: .more, hover: .fill) { openMore() }
                        .background(AnchorProbe(box: moreAnchor))
                } else if slot.action == .send, slot.cost > SheetValues.commandIconCost {
                    TextButton(label: word("mail.action.send"), kind: .accent, disabled: slot.off, action: { run.perform(.send) }) { Glyph(.send) }
                        .opacity(slot.off ? SheetValues.disabledOpacity : 1)
                        .background {
                            Button("") { if slot.off { model.announce(.recipientMissing) } else { run.perform(.send) } }
                                .keyboardShortcut(.return, modifiers: .command)
                                .opacity(0)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                } else if let action = slot.action, let glyph = action.glyph {
                    SymbolButton(help: run.help(action), glyph: glyph, selected: slot.accent, disabled: slot.off, hover: .fill) {
                        run.perform(action)
                    }
                    .keyboardShortcut(action.shortcut)
                }
            }
        }
    }

    private func openMore() {
        guard let rect = moreAnchor.screenRect() else { return }
        let lines: [MailMenuLine]
        switch model.frontRef {
        case .message(let id): lines = MailMenus.readingMore(starred: model.card(id)?.summary.flags.contains(.flagged) ?? false)
        case .draft: lines = MailMenus.draftMore()
        case nil: return
        }
        let entries = MailMenuLine.entries(lines) { run.perform($0) }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthWide, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}
