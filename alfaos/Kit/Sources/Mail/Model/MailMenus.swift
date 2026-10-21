import Foundation
import ShellCore

public enum MailAction: String, Sendable, CaseIterable {
    case reply, replyAll, forward, archive, trash, markRead, markUnread, star, unstar, move, spam
    case note, original, print, pdf, toProject, more, openDraft, copyAddress, writeMail, saveContact, editContact
    case preview, otherProject, saveAs, laterSend, receipt, template, attachFile, fromProject, format
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
        case .format: .textSize
        case .saveDraft: .save
        case .send: .send
        case .overview: .grid
        case .backToStack: .fan
        case .foldColumn: .minus
        default: nil
        }
    }
}

public enum MailMenuLine: Equatable, Sendable {
    case item(MailAction, checked: Bool = false)
    case separator
    case head(String)
}

public enum MailMenus {
    public static func row(unread: Bool, draft: Bool) -> [MailMenuLine] {
        if draft { return [.item(.openDraft)] }
        return [.item(.reply), .item(.forward), .separator, .item(.archive),
                .item(unread ? .markRead : .markUnread), .item(.move), .separator, .item(.trash)]
    }

    public static func readingMore(starred: Bool) -> [MailMenuLine] {
        [.item(starred ? .unstar : .star), .item(.markUnread), .item(.move), .separator,
         .item(.note), .item(.original), .item(.spam)]
    }

    public static func draftMore() -> [MailMenuLine] {
        [.item(.laterSend), .item(.receipt), .item(.template), .separator, .item(.print)]
    }

    public static func person(address: String, contact: Bool) -> [MailMenuLine] {
        [.head(address), .item(.copyAddress), .item(.writeMail), .item(contact ? .editContact : .saveContact)]
    }

    public static func attachment() -> [MailMenuLine] {
        [.item(.preview), .separator, .item(.otherProject), .item(.saveAs)]
    }
}

public enum MailFormatting: String, CaseIterable, Sendable {
    case bold, italic, underline, list, numbered, link

    public var glyph: Icon {
        switch self {
        case .bold: .bold
        case .italic: .italic
        case .underline: .underline
        case .list: .list
        case .numbered: .numbered
        case .link: .link
        }
    }

    public static var items: [MailFormatting] { allCases }
}
