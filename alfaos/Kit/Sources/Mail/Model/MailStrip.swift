import Foundation
import ShellCore

public struct MailStripMark: Identifiable, Equatable, Sendable {
    public enum Face: Equatable, Sendable {
        case glyph(MailGlyph)
        case text(String)
    }

    public enum Run: Equatable, Sendable {
        case folder(String)
        case compose
        case row(String)
        case reply(String)
        case forward(String)
        case card(CardRef)
    }

    public let id: String
    public let face: Face
    public let help: MailFolderName
    public let selected: Bool
    public let dot: Bool
    public let run: Run
}

extension MailModel {
    public func stripMarks(_ lane: Lane, height: Double) -> [MailStripMark] {
        switch lane {
        case .leading:
            return folderRows.map { row in
                MailStripMark(id: "folder." + row.folder.id, face: .glyph(row.glyph), help: folderName(row.folder.id),
                              selected: row.selected, dot: false, run: .folder(row.folder.id))
            } + [composeMark]
        case .center:
            let room = max(1, Int((height - Design.Size.stripReserveTop - Design.Size.stripReserveBottom) / Design.Size.rowHeight))
            return rowPresentations.prefix(room).map { row in
                MailStripMark(id: "row." + row.id, face: row.initials.isEmpty ? .glyph(.person) : .text(row.initials),
                              help: MailFolderName(key: nil, text: row.subject ?? ""), selected: row.selected, dot: row.unread,
                              run: .row(row.id))
            }
        case .trailing:
            let order = visibleStack
            if order.isEmpty { return [composeMark] }
            var marks: [MailStripMark] = []
            if case .message(let id) = frontRef {
                marks.append(MailStripMark(id: "reply", face: .glyph(.reply), help: MailFolderName(key: MailAction.reply.key, text: ""),
                                           selected: false, dot: false, run: .reply(id)))
                marks.append(MailStripMark(id: "forward", face: .glyph(.forward), help: MailFolderName(key: MailAction.forward.key, text: ""),
                                           selected: false, dot: false, run: .forward(id)))
            }
            return marks + order.compactMap { ref in
                switch ref {
                case .message(let id):
                    guard let card = card(id) else { return nil }
                    let initials = MailNames.initials(Self.sender(card.summary).name)
                    return MailStripMark(id: ref.id, face: initials.isEmpty ? .glyph(.person) : .text(initials),
                                         help: MailFolderName(key: nil, text: card.summary.subject), selected: false, dot: false, run: .card(ref))
                case .draft(let id):
                    guard let card = draft(id) else { return nil }
                    let initials = card.people(.to).first.map { MailNames.initials($0.name) } ?? ""
                    return MailStripMark(id: ref.id, face: initials.isEmpty ? .glyph(.compose) : .text(initials),
                                         help: MailFolderName(key: nil, text: card.draft.subject), selected: false, dot: false, run: .card(ref))
                }
            }
        }
    }

    var composeMark: MailStripMark {
        MailStripMark(id: "compose", face: .glyph(.compose), help: MailFolderName(key: "mail.action.compose", text: ""),
                      selected: false, dot: false, run: .compose)
    }

    public func run(_ mark: MailStripMark.Run) async {
        switch mark {
        case .folder(let id): await selectFolder(id)
        case .compose: _ = compose()
        case .row(let id): await open(id)
        case .reply(let id): _ = await reply(to: id)
        case .forward(let id): _ = await forward(id)
        case .card(let ref): bring(ref)
        }
    }
}
