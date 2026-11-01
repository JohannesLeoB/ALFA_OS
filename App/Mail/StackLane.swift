import AppKit
import Carbon.HIToolbox
import Core
import Design
import Mail
import Shell
import SwiftUI

private enum StackKeys {
    static let archive = "e"
    static let deletes: Set<String> = ["\u{7F}", "\u{F728}"]
}

struct StackLane: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var discarding: UUID?

    private var inbox: InboxState { session.inbox }

    private var desk: DeskState { session.desk }

    private var confirming: Bool {
        if let discarding, inbox.frontRef == .draft(discarding) { return true }
        return false
    }

    private var canFold: Bool {
        desk.widths.all.filter { $0 > desk.measure.laneFolded }.count > 1
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let commands = inbox.commands(confirmDiscard: confirming, canFold: canFold,
                                          sendLabelled: width - Tokens.Size.edge >= Tokens.Size.breakpointSendLabel)
            VStack(spacing: 0) {
                head(commands, width: width)
                StackDetail(session: session, commands: commands, perform: perform)
            }
            .focusedSceneValue(\.mailMenu, menuTarget(commands))
        }
        .eventMonitor(.keyDown, active: desk.mode == nil) { sample in handle(sample) }
        .onChange(of: inbox.frontRef) { discarding = nil }
    }

    private func menuTarget(_ commands: CommandSet) -> MailMenuTarget {
        var flags: Set<Flag> = []
        if case .message(let id) = inbox.frontRef { flags = inbox.card(id)?.summary.flags ?? [] }
        var extra: [Action] = []
        if case .draft = inbox.frontRef { extra = [.print] }
        return MailMenuTarget(front: inbox.frontRef, commands: commands, read: flags.contains(.seen), starred: flags.contains(.flagged),
                              perform: perform, extra: extra)
    }

    private func head(_ commands: CommandSet, width: Double) -> some View {
        let plan = CommandBarEngine.plan(main: commands.main, tail: commands.tail, fan: commands.fan, fold: commands.fold,
                                         staticMore: false, width: width - Tokens.Size.edge)
        return CommandHead(plan: plan, moreHelp: appearance.string("settings.action.more"), glyph: { $0.glyph },
                           help: { session.help($0, appearance: appearance) }, shortcut: { $0.shortcut }, perform: perform,
                           more: { actions in
                               MenuLine.entries(actions.map { MenuLine.item($0) }, appearance: appearance, warns: false) { perform($0) }
                           }) {
            ConfirmPill(question: "mail.confirm.discard.question", yes: "mail.confirm.discard.yes", appearance: appearance,
                        startsAsking: true, onYes: {
                            if let id = discarding { Task { await inbox.deleteDraft(id) } }
                            discarding = nil
                        }, onNo: { discarding = nil }) {
                Glyph(.trash)
            }
        }
    }

    private func perform(_ action: Action) {
        if action == .print, case .draft(let id) = inbox.frontRef {
            MessageExport.printDraft(inbox, id, settings: session.settings)
            return
        }
        switch SlotRouter.route(action, front: inbox.frontRef) {
        case .openOverview: inbox.openOverview(true)
        case .closeOverview: inbox.openOverview(false)
        case .fold: desk.toggleFold(.trailing)
        case .saveDraft(let id): Task { await inbox.save(id) }
        case .discardDraft(let id): discarding = id
        case .send(let id): Task { await inbox.send(id) }
        case .attachFile(let id): session.attachFiles(to: id)
        case .toggleFormat: inbox.formatting.toggle()
        case .message(let routed, let id): session.perform(routed, message: id)
        case nil: break
        }
    }

    private func handle(_ sample: EventSample) -> Bool {
        guard sample.local != nil, !inbox.overview.open, case .message(let id) = inbox.frontRef else { return false }
        guard sample.event.modifierFlags.intersection([.command, .control]).isEmpty else { return false }
        if sample.event.window?.firstResponder is NSText { return false }
        let key = sample.event.charactersIgnoringModifiers?.lowercased() ?? ""
        if key == StackKeys.archive, inbox.folderActions {
            session.perform(.archive, message: id)
            return true
        }
        if StackKeys.deletes.contains(key), !inbox.inTrash(id) {
            session.perform(.trash, message: id)
            return true
        }
        return false
    }
}

struct StackDetail: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let commands: CommandSet
    let perform: (Action) -> Void

    private var inbox: InboxState { session.inbox }

    var body: some View {
        CardStack(order: inbox.stackOrder, overviewOpen: inbox.overview.open) { ref, depth in
            MessageCard(session: session, ref: ref, depth: depth, commands: commands, perform: perform)
        } overview: {
            OverviewList(session: session)
        }
    }
}

struct OverviewList: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession

    private var inbox: InboxState { session.inbox }

    private var entries: [(entry: OverviewEntry, ref: CardRef)] {
        inbox.stackOrder.compactMap { ref in
            switch ref {
            case .message(let id):
                guard let card = inbox.card(id) else { return nil }
                let party = inbox.party(card.summary)
                let name = party.name.isEmpty ? PersonName.middle(party.address, limit: SheetValues.cardTitleLimit) : party.name
                let initials = PersonName.initials(party.name)
                let entry = OverviewEntry(id: ref.id, mark: initials.isEmpty ? .icon(.person) : .text(initials), title: Text(verbatim: name),
                                          date: MessageDate.text(DateLabel.of(card.summary.receivedAt, now: inbox.now), draft: false, appearance: appearance),
                                          unread: !card.summary.flags.contains(.seen), subject: card.summary.subject,
                                          preview: inbox.preview(card.summary), current: inbox.frontRef == ref, close: { inbox.close(id) },
                                          commands: commands(id), choose: { choose(ref) })
                return (entry, ref)
            case .draft(let id):
                guard let card = inbox.draft(id) else { return nil }
                let first = card.addressees.first
                let entry = OverviewEntry(id: ref.id, mark: .icon(.compose),
                                          title: first.map { Text(verbatim: appearance.format("mail.row.to", $0.label)) } ?? appearance.text("mail.row.newMessage"),
                                          date: appearance.text("mail.date.draft"), unread: false,
                                          subject: card.draft.subject.isEmpty ? appearance.string("mail.draft.noSubject") : card.draft.subject,
                                          preview: card.draft.body, current: inbox.frontRef == ref,
                                          close: { Task { await inbox.closeDraft(id) } }, choose: { choose(ref) })
                return (entry, ref)
            }
        }
    }

    private func commands(_ id: String) -> [OverviewCommand] {
        [OverviewCommand(id: Action.reply.rawValue, help: appearance.string(Action.reply.key), icon: .reply, tone: \.inkSecondary) {
            session.perform(.reply, message: id)
        },
         OverviewCommand(id: Action.archive.rawValue, help: appearance.string(Action.archive.key), icon: .archive, tone: \.inkSecondary) {
            session.perform(.archive, message: id)
        },
         OverviewCommand(id: Action.trash.rawValue, help: appearance.string(Action.trash.key), icon: .trash, tone: \.signal) {
            session.perform(.trash, message: id)
        }].filter { (inbox.folderActions || $0.id != Action.archive.rawValue) && (!inbox.inTrash(id) || $0.id != Action.trash.rawValue) }
    }

    var body: some View {
        let items = entries
        OverviewGrid(entries: items.map(\.entry), size: .medium, hot: inbox.overview.hot?.id,
                     aim: { id in inbox.aimOverview(id.flatMap { id in items.first { $0.entry.id == id }?.ref }) })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(appearance.color(\.lane))
    }

    private func choose(_ ref: CardRef) {
        inbox.bring(ref)
        inbox.openOverview(false)
    }
}

struct MessageTiles: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    @Binding var window: Int

    private var inbox: InboxState { session.inbox }

    var body: some View {
        let listed = inbox.rowWindow(limit: window + 1)
        MessageTileGrid(session: session, entries: entries(of: listed.items.prefix(window)), more: { more(total: listed.total) })
    }

    private func more(total: Int) {
        inbox.extend(&window, total: total)
    }

    private func entries(of rows: ArraySlice<RowPresentation>) -> [OverviewEntry] {
        rows.map { row in
            OverviewEntry(id: row.id, mark: row.initials.isEmpty ? .icon(.person) : .text(row.initials),
                          title: row.title(appearance),
                          date: MessageDate.text(row.date, draft: row.draft, appearance: appearance), unread: row.unread,
                          subject: row.tileSubject(appearance), preview: row.preview ?? "",
                          current: row.selected, commands: row.draft ? [] : commands(row.id),
                          choose: { if row.draft { Task { await inbox.editDraft(row.id) } } else { Task { await inbox.open(row.id) } } })
        }
    }

    private func commands(_ id: String) -> [OverviewCommand] {
        [OverviewCommand(id: Action.reply.rawValue, help: appearance.string(Action.reply.key), icon: .reply, tone: \.inkSecondary) {
            session.perform(.reply, message: id)
        },
         OverviewCommand(id: Action.archive.rawValue, help: appearance.string(Action.archive.key), icon: .archive, tone: \.inkSecondary) {
            session.perform(.archive, message: id)
        },
         OverviewCommand(id: Action.trash.rawValue, help: appearance.string(Action.trash.key), icon: .trash, tone: \.signal) {
            session.perform(.trash, message: id)
        }].filter { (inbox.folderActions || $0.id != Action.archive.rawValue) && (!inbox.inTrash(id) || $0.id != Action.trash.rawValue) }
    }
}

private struct MessageTileGrid: View {
    let session: AppSession
    let entries: [OverviewEntry]
    let more: () -> Void

    var body: some View {
        OverviewGrid(entries: entries, size: .medium, hot: session.inbox.tileHot, still: true,
                     aim: { session.inbox.aimTile($0) }, more: more)
    }
}

struct SheetDetail: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenMessage

    private var loadImages: Bool { session.settings.loadImages(card.inlet) }

    var body: some View {
        let items = session.inbox.thread(card.id)
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: card.summary.subject.isEmpty ? appearance.string("mail.row.noSubject") : card.summary.subject)
                .font(.face(Tokens.TextStyle.title.size, weight: Tokens.Weight.medium))
                .tracking(CGFloat(Tokens.TextStyle.title.tracking * Tokens.TextStyle.title.size))
                .lineHeight(Tokens.TextStyle.title.lineHeight, size: Tokens.TextStyle.title.size)
                .fixedSize(horizontal: false, vertical: true)
            if card.hasConversation {
                Text(verbatim: appearance.format("mail.read.conversation", String(card.conversation.count)))
                    .font(.face(Tokens.TextSize.small))
                    .foregroundStyle(appearance.color(\.sheetInkTertiary))
                    .padding(.top, CGFloat(Tokens.Spacing.step4))
            }
            if let list = card.listNotice {
                Notice(kind: .warning, title: appearance.text("mail.list.banner"), text: nil, onSheet: true,
                       glyph: { Glyph(.envelope) },
                       actions: { listAction(list) })
                    .padding(.horizontal, -CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step16))
            }
            if card.remoteImagesBlocked(loadRemote: loadImages) {
                Notice(kind: .warning, title: appearance.text("mail.read.images.title"), text: appearance.text("mail.read.images.text"), onSheet: true,
                       glyph: { Glyph(.alert) },
                       actions: { TextButton(label: appearance.text("mail.action.loadImages"), kind: .sheet) { session.inbox.allowRemoteImages(card.id) } })
                    .padding(.horizontal, -CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step16))
            }
            if card.bodyFailed {
                Notice(kind: .failure, title: appearance.text("mail.failure.read"), text: nil, onSheet: true,
                       glyph: { Glyph(.alert) },
                       actions: { TextButton(label: appearance.text("mail.list.failed.act"), kind: .sheet) { session.inbox.retryBody(card.id) } })
                    .padding(.horizontal, -CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step16))
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ThreadItemRow(session: session, card: card, item: item, first: index == 0, last: index == items.count - 1)
            }
        }
        .padding(.top, CGFloat(Tokens.Spacing.step16))
        .padding(.bottom, CGFloat(Tokens.Spacing.step24))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(appearance.color(\.sheetInk))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.sheet)))
        .environment(\.colorScheme, .light)
        .textSelection(.enabled)
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .padding(.bottom, CGFloat(Tokens.Spacing.step8))
    }

    @ViewBuilder
    private func listAction(_ list: ListUnsubscribe) -> some View {
        if list.unsubscribes {
            ConfirmPill(label: appearance.text("mail.list.unsubscribe"), question: appearance.text("mail.list.unsubscribeQuestion"),
                        yes: appearance.text("mail.list.unsubscribe"), no: appearance.text("confirm.no"),
                        holdHint: Text(verbatim: appearance.format("settings.confirm.hold", appearance.string("mail.list.unsubscribe"))),
                        showsProgress: false,
                        onYes: {
                Task {
                    if let page = await session.inbox.unsubscribe(card.id) { NSWorkspace.shared.open(page) }
                }
            })
        } else if let page = list.web {
            TextButton(label: appearance.text("mail.list.website"), kind: .sheet) { NSWorkspace.shared.open(page) }
        }
    }
}
