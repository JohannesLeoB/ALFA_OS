import Mail
import ShellCore
import SwiftUI

struct OverviewView: View {
    @Environment(\.mailLaneLink) private var link
    let model: MailModel

    private var title: String { folderTitle(model.currentFolderName) }

    private var modes: [SegmentOption<MailOverviewMode>] {
        [SegmentOption(id: .stack, label: line("mail.overview.stack", String(model.stackCount))),
         SegmentOption(id: .folder, label: line("mail.overview.folder", title, String(model.rows.count)))]
    }

    private var entries: [(entry: OverviewEntry, ref: CardRef)] {
        if model.overview.mode == .folder {
            return model.rowPresentations.map { row in
                let entry = OverviewEntry(id: row.id, mark: row.initials.isEmpty ? .icon(row.draft ? .compose : .person) : .text(row.initials),
                                          title: row.outgoing ? line("mail.row.to", row.sender) : Text(verbatim: row.sender),
                                          date: dateText(row.date), unread: row.unread, subject: row.subject ?? "", preview: row.preview ?? "",
                                          current: model.frontRef == .message(row.id), commands: row.draft ? [] : commands(row.id),
                                          choose: { if row.draft { openDraft(row.id) } else { open(row.id) } })
                return (entry, .message(row.id))
            }
        }
        return model.stackOrder.compactMap { ref in
            switch ref {
            case .message(let id):
                guard let card = model.card(id) else { return nil }
                let party = model.party(card.summary)
                let name = party.name.isEmpty ? MailNames.middle(party.address, limit: SheetValues.cardTitleLimit) : party.name
                let initials = MailNames.initials(party.name)
                let entry = OverviewEntry(id: ref.id, mark: initials.isEmpty ? .icon(.person) : .text(initials), title: Text(verbatim: name),
                                          date: dateText(MailDateLabel.of(card.summary.receivedAt, now: model.now)),
                                          unread: !card.summary.flags.contains(.seen), subject: card.summary.subject,
                                          preview: card.summary.snippet, current: model.frontRef == ref, close: { model.close(id) },
                                          commands: commands(id), choose: { choose(ref) })
                return (entry, ref)
            case .draft(let id):
                guard let card = model.draft(id) else { return nil }
                let first = card.people(.to).first
                let entry = OverviewEntry(id: ref.id, mark: .icon(.compose),
                                          title: first.map { line("mail.row.to", $0.label) } ?? word("mail.row.newMessage"),
                                          date: word("mail.date.draft"), unread: false,
                                          subject: card.draft.subject.isEmpty ? words("mail.row.newMessage") : card.draft.subject,
                                          preview: card.draft.body, current: model.frontRef == ref,
                                          close: { Task { await model.closeDraft(id) } }, choose: { choose(ref) })
                return (entry, ref)
            }
        }
    }

    private func commands(_ id: String) -> [OverviewCommand] {
        let run = MailDo(model: model)
        return [OverviewCommand(id: "reply", help: words("mail.action.reply"), icon: .reply, tone: \.inkSecondary) { run.message(.reply, id) },
                OverviewCommand(id: "archive", help: words("mail.action.archive"), icon: .archive, tone: \.inkSecondary) { run.message(.archive, id) },
                OverviewCommand(id: "trash", help: words("mail.action.trash"), icon: .trash, tone: \.signal) { run.message(.trash, id) }]
    }

    private func dateText(_ label: MailDateLabel) -> Text {
        switch label {
        case .time(let date): Text(date, format: .dateTime.hour().minute())
        case .yesterday: word("mail.date.yesterday")
        case .weekday(let date): Text(date, format: .dateTime.weekday(.wide))
        case .day(let date): Text(date, format: .dateTime.day().month(.abbreviated))
        case .draft: word("mail.date.draft")
        case .none: Text(verbatim: "")
        }
    }

    var body: some View {
        let items = entries
        CardOverview(entries: items.map(\.entry), size: model.overview.size, resize: { model.setOverviewSize($0) },
                     hot: model.overview.hot?.id,
                     aim: { id in model.aimOverview(id.flatMap { id in items.first { $0.entry.id == id }?.ref }) }) {
            SegmentedControl(options: modes, selection: Binding(get: { model.overview.mode }, set: { model.setOverviewMode($0) }))
        }
        .onAppear { grow(true) }
        .onDisappear { grow(false) }
    }

    private func grow(_ on: Bool) {
        guard let link else { return }
        if on, link.maximized != .trailing { link.toggleMaximize(.trailing) }
        if !on, link.maximized == .trailing { link.toggleMaximize(.trailing) }
    }

    private func choose(_ ref: CardRef) {
        model.bring(ref)
        model.openOverview(false)
    }

    private func open(_ id: String) {
        model.openOverview(false)
        Task { await model.open(id) }
    }

    private func openDraft(_ id: String) {
        model.openOverview(false)
        Task { _ = await model.editDraft(id) }
    }
}
