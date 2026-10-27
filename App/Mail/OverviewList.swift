import Core
import Design
import Mail
import Shell
import SwiftUI

struct OverviewList: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession

    private var inbox: InboxState { session.inbox }

    private var title: String { FolderTitle.text(inbox.currentFolderName, localized: appearance.string) }

    private var modes: [SegmentOption<OverviewMode>] {
        [SegmentOption(id: .stack, label: Text(verbatim: appearance.format("mail.overview.stack", String(inbox.stackCount)))),
         SegmentOption(id: .folder, label: Text(verbatim: appearance.format("mail.overview.folder", title, String(inbox.rows.count))))]
    }

    private var entries: [(entry: OverviewEntry, ref: CardRef)] {
        if inbox.overview.mode == .folder {
            return inbox.rowPresentations.map { row in
                let entry = OverviewEntry(id: row.id, mark: row.initials.isEmpty ? .icon(row.draft ? .compose : .person) : .text(row.initials),
                                          title: row.outgoing ? Text(verbatim: appearance.format("mail.row.to", row.sender)) : Text(verbatim: row.sender),
                                          date: MessageDate.text(row.date, draft: row.draft, appearance: appearance), unread: row.unread,
                                          subject: row.subject ?? "", preview: row.preview ?? "",
                                          current: inbox.frontRef == .message(row.id), commands: row.draft ? [] : commands(row.id),
                                          choose: { if row.draft { openDraft(row.id) } else { open(row.id) } })
                return (entry, .message(row.id))
            }
        }
        return inbox.stackOrder.compactMap { ref in
            switch ref {
            case .message(let id):
                guard let card = inbox.card(id) else { return nil }
                let party = inbox.party(card.summary)
                let name = party.name.isEmpty ? PersonName.middle(party.address, limit: SheetValues.cardTitleLimit) : party.name
                let initials = PersonName.initials(party.name)
                let entry = OverviewEntry(id: ref.id, mark: initials.isEmpty ? .icon(.person) : .text(initials), title: Text(verbatim: name),
                                          date: MessageDate.text(DateLabel.of(card.summary.receivedAt, now: inbox.now), draft: false, appearance: appearance),
                                          unread: !card.summary.flags.contains(.seen), subject: card.summary.subject,
                                          preview: card.summary.snippet, current: inbox.frontRef == ref, close: { inbox.close(id) },
                                          commands: commands(id), choose: { choose(ref) })
                return (entry, ref)
            case .draft(let id):
                guard let card = inbox.draft(id) else { return nil }
                let first = card.people(.to).first
                let entry = OverviewEntry(id: ref.id, mark: .icon(.compose),
                                          title: first.map { Text(verbatim: appearance.format("mail.row.to", $0.label)) } ?? appearance.text("mail.row.newMessage"),
                                          date: appearance.text("mail.date.draft"), unread: false,
                                          subject: card.draft.subject.isEmpty ? appearance.string("mail.row.newMessage") : card.draft.subject,
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
        }]
    }

    var body: some View {
        let items = entries
        CardOverview(entries: items.map(\.entry), size: inbox.overview.size, resize: { inbox.setOverviewSize($0) },
                     hot: inbox.overview.hot?.id,
                     aim: { id in inbox.aimOverview(id.flatMap { id in items.first { $0.entry.id == id }?.ref }) }) {
            SegmentedControl(options: modes, selection: Binding(get: { inbox.overview.mode }, set: { inbox.setOverviewMode($0) }))
        }
        .onAppear { grow(true) }
        .onDisappear { grow(false) }
    }

    private func grow(_ on: Bool) {
        let desk = session.desk
        let maximized = desk.laneMode(desk.currentID).maximized
        if on, maximized != .trailing { desk.toggleMaximize(.trailing) }
        if !on, maximized == .trailing { desk.toggleMaximize(.trailing) }
    }

    private func choose(_ ref: CardRef) {
        inbox.bring(ref)
        inbox.openOverview(false)
    }

    private func open(_ id: String) {
        inbox.openOverview(false)
        Task { await inbox.open(id) }
    }

    private func openDraft(_ id: String) {
        inbox.openOverview(false)
        Task { await inbox.editDraft(id) }
    }
}
