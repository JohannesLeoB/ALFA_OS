import AppKit
import Core
import Design
import Mail
import Shell
import SwiftUI

struct MessageCard: View {
    let session: AppSession
    let ref: CardRef
    let depth: Int
    let commands: CommandSet
    let perform: (Action) -> Void

    var body: some View {
        CardFace(depth: depth, lacquered: true, last: depth == session.inbox.stackOrder.count - 1,
                 bring: { session.inbox.bring(ref) }) { ink in
            Head(session: session, ref: ref, depth: depth, ink: ink)
        } content: {
            content
            if commands.hasFooter {
                Foot(session: session, commands: commands, perform: perform)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch ref {
        case .message(let id):
            if let card = session.inbox.card(id) { MessageDetail(session: session, card: card) }
        case .draft(let id):
            if let card = session.inbox.draft(id) { DraftEditor(session: session, card: card) }
        }
    }
}

struct MessageDetail: View {
    let session: AppSession
    let card: OpenMessage

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    RecipientDetail(session: session, card: card)
                    SheetDetail(session: session, card: card)
                }
            }
            .scrollIndicators(.automatic)
            .task(id: card.id) {
                if !card.summary.threadID.isEmpty, card.conversation.isEmpty { await session.inbox.loadThreadTexts(card.id) }
                reveal(proxy)
            }
            .onChange(of: card.conversation.count) { reveal(proxy) }
        }
    }

    private func reveal(_ proxy: ScrollViewProxy) {
        guard card.hasConversation, session.inbox.thread(card.id).first?.id != card.id else { return }
        proxy.scrollTo(card.id, anchor: .top)
    }
}

extension MessageCard {
    struct Head: View {
        @Environment(\.appearance) private var appearance
        let session: AppSession
        let ref: CardRef
        let depth: Int
        let ink: Color
        @State private var titleAnchor = AnchorBox()

        private var inbox: InboxState { session.inbox }

        private var front: Bool { depth == 0 }

        private var saving: Bool {
            guard front, case .draft(let id) = ref else { return false }
            return inbox.draft(id)?.state == .saving
        }

        var body: some View {
            CardHeader(front: front, ink: ink) {
                markView
            } title: {
                titleView
            } meta: {
                metaView
                    .font(.face(Tokens.TextSize.small))
                    .foregroundStyle(ink)
                    .opacity(CardStackEngine.metaOpacity(depth: depth))
            } trailing: {
                if case .message(let id) = ref, inbox.card(id)?.pinned == false {
                    CardHeadButton(help: appearance.string("mail.card.pin.tip"), glyph: .pin, ink: ink) { inbox.pin(id) }
                }
                CardHeadButton(help: appearance.string("card.close"), glyph: .close, ink: ink, fills: false, disabled: saving) { close() }
            }
        }

        private func close() {
            switch ref {
            case .message(let id): inbox.close(id)
            case .draft(let id): Task { await inbox.closeDraft(id) }
            }
        }

        private var party: (name: String, address: String)? {
            guard case .message(let id) = ref, let card = inbox.card(id) else { return nil }
            return inbox.party(card.summary)
        }

        private var draftPeople: [Participant] {
            guard case .draft(let id) = ref, let card = inbox.draft(id) else { return [] }
            return card.addressees
        }

        @ViewBuilder
        private var markView: some View {
            if let party {
                let initials = PersonName.initials(party.name)
                if initials.isEmpty { Glyph(.person) } else { Text(verbatim: initials) }
            } else {
                Glyph(.compose)
            }
        }

        @ViewBuilder
        private var titleView: some View {
            if case .message = ref, let party {
                let name = party.name.isEmpty ? PersonName.middle(party.address, limit: SheetValues.cardTitleLimit) : party.name
                Text(verbatim: name)
                    .designText(size: Tokens.TextSize.body, weight: .medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(Text(verbatim: front ? party.address : ""))
                    .background(AnchorMarker(box: titleAnchor))
                    .onTapGesture { if front { personMenu(party: party) } }
            } else if case .draft = ref {
                Group {
                    if let first = draftPeople.first {
                        Text(verbatim: appearance.format("mail.row.to", first.label))
                    } else {
                        appearance.text("mail.row.newMessage")
                    }
                }
                .designText(size: Tokens.TextSize.body, weight: .medium)
                .lineLimit(1)
                .truncationMode(.tail)
            }
        }

        private func personMenu(party: (name: String, address: String)) {
            let entries = session.personEntries(name: party.name, address: party.address, appearance: appearance)
            titleAnchor.showMenu(entries)
        }

        @ViewBuilder
        private var metaView: some View {
            if case .message(let id) = ref, let card = inbox.card(id), let party {
                if front {
                    Text(verbatim: party.name.isEmpty ? "" : PersonName.middle(party.address, limit: SheetValues.cardAddressLimit))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                    MessageDate.text(DateLabel.of(card.summary.receivedAt, now: inbox.now), draft: false, appearance: appearance)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
            } else if case .draft(let id) = ref, let card = inbox.draft(id) {
                let more = max(0, draftPeople.count - 1)
                if !front && more > 0 {
                    Spacer(minLength: 0)
                    Text(verbatim: appearance.format("mail.read.more", Format.number(more)))
                        .lineLimit(1)
                } else {
                    draftMeta(card)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        private func draftMeta(_ card: OpenDraft) -> Text {
            guard front else { return Text(verbatim: card.draft.subject) }
            return card.status.map { appearance.text($0.key) } ?? Text(verbatim: card.draft.subject)
        }
    }
}

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
                    slotView(slot).background { if slot.action == .send { sendKey } }
                }
            }
        }

        @ViewBuilder
        private func slotView(_ slot: Slot) -> some View {
            if slot.kind == .more {
                SymbolButton(help: appearance.string("settings.action.more"), glyph: .more, tone: \.inkSecondary, hover: .fill) { openMore() }
                    .background(AnchorMarker(box: moreAnchor))
            } else if slot.action == .send, slot.cost > ShellValues.commandIconCost {
                TextButton(label: appearance.text("mail.action.send"), kind: .accent, disabled: slot.off, action: { perform(.send) }) { Glyph(.send) }
            } else if let action = slot.action, action == .fromProject || action == .toProject, let glyph = action.glyph {
                SymbolButton(help: session.help(action, appearance: appearance), glyph: glyph, disabled: slot.off, tone: \.inkSecondary, hover: .fill) { openProjects() }
                    .background(AnchorMarker(box: projectAnchor))
            } else if let action = slot.action, let glyph = action.glyph {
                SymbolButton(help: session.help(action, appearance: appearance), glyph: glyph, selected: slot.accent, disabled: slot.off, tone: \.inkSecondary,
                             hover: .fill) {
                    perform(action)
                }
                .keyboardShortcut(action.shortcut)
            }
        }

        private var sendKey: some View {
            Button("") { submit() }
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }

        private func submit() {
            NSApp.keyWindow?.makeFirstResponder(nil)
            Task { @MainActor in
                await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
                guard case .draft(let id) = inbox.frontRef else { return }
                if inbox.draft(id)?.canSend == true { perform(.send) } else { inbox.refuseSend(id) }
            }
        }

        private func openProjects() {
            switch inbox.frontRef {
            case .draft(let id): ProjectFolderList.show(session, appearance: appearance, draft: id, anchor: projectAnchor)
            case .message(let id): ProjectFolderList.save(session, appearance: appearance, message: id, anchor: projectAnchor)
            case nil: break
            }
        }

        private func openMore() {
            if case .draft(let id) = inbox.frontRef {
                moreAnchor.showMenu(MenuLine.entries(MenuEngine.draftMore(receipt: inbox.asksReceipt(id)), appearance: appearance) { action in
                    switch action {
                    case .print: MessageExport.printDraft(inbox, id, settings: session.settings)
                    case .laterSend: moreAnchor.showMenu(planEntries(id))
                    default: inbox.toggleReceipt(id)
                    }
                })
                return
            }
            guard case .message(let id) = inbox.frontRef else { return }
            let lines = MenuEngine.readingMore(starred: inbox.card(id)?.summary.flags.contains(.flagged) ?? false, original: inbox.offersOriginal,
                                               unread: !(inbox.card(id)?.summary.flags.contains(.seen) ?? true),
                                               folders: inbox.folderActions, spam: inbox.offersSpam)
            let entries = MenuLine.entries(lines, appearance: appearance) { action in
                if action == .move {
                    moreAnchor.showMenu(MoveFolderList.entries(inbox, appearance: appearance, message: id))
                } else if action == .original {
                    SourceWindow.show(inbox, message: id, appearance: appearance)
                } else {
                    perform(action)
                }
            }
            moreAnchor.showMenu(entries)
        }

        private func planEntries(_ id: UUID) -> [MenuEntry] {
            let now = inbox.now
            let rows = inbox.planChoices.enumerated().map { index, date in
                MenuEntry.row(MenuItem(id: String(index), label: Text(verbatim: MessageDate.plan(date, now: now, appearance: appearance))) {
                    Task { await inbox.plan(id, at: date) }
                })
            }
            let custom = MenuEntry.row(MenuItem(id: "custom", label: appearance.text("mail.later.custom")) { inbox.pickPlan(id) })
            return [.head(id: "head", label: appearance.text("mail.later.folder"))] + rows + [.separator(id: "line"), custom]
        }
    }
}
