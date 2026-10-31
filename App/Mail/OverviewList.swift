import Core
import Design
import Mail
import Shell
import SwiftUI

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
            + (inbox.inTrash(id) && inbox.canPurge(id)
                ? [OverviewCommand(id: Action.purge.rawValue, help: appearance.string(Action.purge.key), icon: .trash, tone: \.signal) {
                    choose(.message(id))
                    inbox.askPurge(id)
                }] : [])
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
