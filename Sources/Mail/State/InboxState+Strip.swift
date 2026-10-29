import Design
import Shell

extension InboxState {
    public func stripMarks(_ lane: LaneKind, height: Double) -> [StripMark] {
        switch lane {
        case .leading:
            return folderRows.map { row in
                StripMark(id: "folder." + row.folder.id, face: .glyph(row.glyph), help: folderName(row.folder.id),
                          selected: row.selected, dot: false, run: .folder(row.folder.id))
            } + [composeMark]
        case .center:
            let room = max(1, Int((height - Tokens.Size.stripReserveTop - Tokens.Size.stripReserveBottom) / Tokens.Size.rowHeight))
            return rowWindow(limit: room).items.map { row in
                StripMark(id: "row." + row.id, face: row.initials.isEmpty ? .glyph(.person) : .text(row.initials),
                          help: FolderName(key: nil, text: row.subject ?? ""), selected: row.selected, dot: row.unread,
                          run: .row(row.id))
            }
        case .trailing:
            let order = visibleStack
            if order.isEmpty { return [composeMark] }
            var marks: [StripMark] = []
            if case .message(let id) = frontRef {
                marks.append(StripMark(id: "reply", face: .glyph(.reply), help: FolderName(key: Action.reply.key, text: ""),
                                       selected: false, dot: false, run: .reply(id)))
                marks.append(StripMark(id: "forward", face: .glyph(.forward), help: FolderName(key: Action.forward.key, text: ""),
                                       selected: false, dot: false, run: .forward(id)))
            }
            return marks + order.compactMap { ref in
                switch ref {
                case .message(let id):
                    guard let card = card(id) else { return nil }
                    let initials = PersonName.initials(Self.sender(card.summary).name)
                    return StripMark(id: ref.id, face: initials.isEmpty ? .glyph(.person) : .text(initials),
                                     help: FolderName(key: nil, text: card.summary.subject), selected: false, dot: false, run: .card(ref))
                case .draft(let id):
                    guard let card = draft(id) else { return nil }
                    let initials = card.people(.to).first.map { PersonName.initials($0.name) } ?? ""
                    return StripMark(id: ref.id, face: initials.isEmpty ? .glyph(.compose) : .text(initials),
                                     help: FolderName(key: nil, text: card.draft.subject), selected: false, dot: false, run: .card(ref))
                }
            }
        }
    }

    var composeMark: StripMark {
        StripMark(id: "compose", face: .glyph(.compose), help: FolderName(key: "mail.action.compose", text: ""),
                  selected: false, dot: false, run: .compose)
    }

    public func run(_ mark: StripMark.Run) async {
        switch mark {
        case .folder(let id): await selectFolder(id)
        case .compose: compose()
        case .row(let id): await open(id)
        case .reply(let id): await reply(to: id)
        case .forward(let id): await forward(id)
        case .card(let ref): bring(ref)
        }
    }
}
