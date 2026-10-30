import Core
import Design
import Mail
import Shell
import SwiftUI

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
