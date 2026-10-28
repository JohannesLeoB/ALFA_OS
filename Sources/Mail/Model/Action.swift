import Shell

public enum Action: String, Sendable, CaseIterable {
    case reply, replyAll, forward, archive, trash, markRead, markUnread, star, unstar, spam
    case print, pdf, toProject, more, openDraft, copyAddress, writeMail, saveContact, editContact
    case saveAs, attachFile, fromProject, move, original
    case saveDraft, discardDraft, send, overview, backToStack, foldColumn, loadImages, purge

    public var key: String { "mail.action." + rawValue }

    public var danger: Bool { self == .trash || self == .discardDraft }

    public var glyph: Icon? {
        switch self {
        case .reply: .reply
        case .replyAll: .replyAll
        case .forward: .forward
        case .archive: .archive
        case .trash, .discardDraft: .trash
        case .print: .print
        case .pdf: .export
        case .toProject, .fromProject: .folder
        case .more: .more
        case .saveContact: .personAdd
        case .attachFile: .attach
        case .saveDraft: .save
        case .send: .send
        case .overview: .grid
        case .backToStack: .fan
        case .foldColumn: .minus
        default: nil
        }
    }
}

public enum MenuLine: Equatable, Sendable {
    case item(Action, checked: Bool = false)
    case separator
    case head(String)
}
