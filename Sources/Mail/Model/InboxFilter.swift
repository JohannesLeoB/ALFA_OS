import Foundation
import Hub
import Shell

public enum InboxFilter: Equatable, Sendable, CaseIterable {
    case all
    case unread
    case attachments

    func matches(_ summary: MessageSummary) -> Bool {
        switch self {
        case .all: true
        case .unread: !summary.flags.contains(.seen)
        case .attachments: summary.attachmentCount > 0
        }
    }
}

public enum SearchScope: Equatable, Sendable {
    case here
    case all
}

enum MoveTarget: Equatable {
    case archive
    case trash
    case spam
}

public enum BulkAction: Equatable, Sendable {
    case read
    case archive
    case trash
}

public enum ListState: Equatable, Sendable {
    case empty(folder: String)
    case emptySearch(query: String, folder: String)
    case loading
    case loadingMore
    case loaded
    case noFilterMatch
    case failed(Hint)
    case notConnected(Inlet.ID?)
    case signInExpired(Inlet.ID)
    case offline(lastSync: Date?)
}

enum LoadPhase: Equatable {
    case settled
    case loading
    case loadingMore
    case failed(Hint)
    case notConnected
    case offline(Date?)
}

public struct RowWindow: Equatable, Sendable {
    public let items: [RowPresentation]
    public let total: Int
}

public enum ListTail: Equatable, Sendable {
    case older
    case moreResults

    public var key: String {
        switch self {
        case .older: "mail.list.older"
        case .moreResults: "mail.list.moreResults"
        }
    }
}

public enum CardRef: Hashable, Sendable {
    case message(String)
    case draft(UUID)

    public var id: String {
        switch self {
        case .message(let id): id
        case .draft(let id): id.uuidString
        }
    }
}

public struct Overview: Equatable, Sendable {
    public var open = false
    public var hot: CardRef?
}

public struct StripMark: Identifiable, Equatable, Sendable {
    public enum Run: Equatable, Sendable {
        case folder(String)
        case compose
        case row(String)
        case reply(String)
        case forward(String)
        case card(CardRef)
    }

    public let id: String
    public let face: StripFace
    public let help: FolderName
    public let selected: Bool
    public let dot: Bool
    public var accent = false
    public let run: Run
}

struct ParkedMailbox {
    var stack: [CardRef] = []
    var front: CardRef?
    var message: String?
}

public enum Action: String, Sendable, CaseIterable {
    case reply, replyAll, forward, archive, trash, markRead, markUnread, star, unstar, spam
    case print, pdf, preview, otherProject, toProject, more, openDraft, copyAddress, writeMail, saveContact, editContact
    case saveAs, attachFile, fromProject, move, original, receipt, format, laterSend
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
        case .backToStack: .close
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

public enum ToastKind: Equatable, Sendable {
    case archived
    case trashed
    case moved
    case inTrash
    case purged
    case draftSaved
    case inOutbox
    case notSentInDrafts
    case outboxSent
    case recipientMissing
    case subjectMissing
    case addressCopied
    case projectSaved(String)
    case attachmentCopied(String)
    case projectSaveFailed
    case pdfSaved
    case pdfFailed
    case contactSaved(String)
    case contactExists(String)
    case contactRemoved
    case bulkRead(count: Int, read: Bool)
    case bulkArchived(count: Int)
    case bulkTrashed(count: Int)
    case olderFailed
    case moreFailed
    case archiveFailed
    case moveFailed
    case deleteFailed
    case flagFailed
    case readFailed
    case attachmentFailed
    case threadFailed
    case searchPartial
    case mirrorRefused
    case planned(Date)
    case inDrafts
    case unsubscribed(String)

    public var key: String {
        switch self {
        case .archived: "mail.toast.archived"
        case .trashed: "mail.toast.trashed"
        case .moved: "mail.toast.moved"
        case .inTrash: "mail.toast.inTrash"
        case .purged: "mail.toast.purged"
        case .draftSaved: "mail.toast.draftSaved"
        case .inOutbox: "mail.draft.outbox"
        case .notSentInDrafts: "mail.toast.notSentInDrafts"
        case .outboxSent: "mail.outbox.toast.sent"
        case .recipientMissing: "mail.toast.recipientMissing"
        case .subjectMissing: "mail.toast.subjectMissing"
        case .addressCopied: "mail.toast.addressCopied"
        case .projectSaved: "mail.toast.projectSaved"
        case .attachmentCopied: "mail.toast.attachmentCopied"
        case .projectSaveFailed: "mail.failure.projectSave"
        case .pdfSaved: "mail.toast.pdfSaved"
        case .pdfFailed: "mail.failure.pdf"
        case .contactSaved: "mail.toast.contactSaved"
        case .contactExists: "mail.toast.contactExists"
        case .contactRemoved: "mail.toast.contactRemoved"
        case .bulkRead(let count, let read): "mail.toast.bulkRead." + (read ? "read" : "unread") + Self.plural(count)
        case .bulkArchived(let count): "mail.toast.bulkArchived" + Self.plural(count)
        case .bulkTrashed(let count): "mail.toast.bulkTrashed" + Self.plural(count)
        case .olderFailed: "mail.toast.olderFailed"
        case .moreFailed: "mail.toast.moreFailed"
        case .archiveFailed: "mail.failure.archive"
        case .moveFailed: "mail.failure.move"
        case .deleteFailed: "mail.failure.delete"
        case .flagFailed: "mail.failure.flag"
        case .readFailed: "mail.failure.read"
        case .attachmentFailed: "mail.failure.attachment"
        case .threadFailed: "mail.failure.thread"
        case .searchPartial: "mail.toast.searchPartial"
        case .mirrorRefused: "mail.hint.mirrorRefused"
        case .planned: "mail.later.planned"
        case .inDrafts: "mail.toast.inDrafts"
        case .unsubscribed: "mail.toast.unsubscribed"
        }
    }

    public var failed: Bool {
        switch self {
        case .olderFailed, .moreFailed, .archiveFailed, .moveFailed, .deleteFailed, .flagFailed, .readFailed, .attachmentFailed,
             .threadFailed, .projectSaveFailed, .pdfFailed, .notSentInDrafts: true
        default: false
        }
    }

    public var actionKey: String {
        switch self {
        case .notSentInDrafts: "mail.draft.failed.act"
        default: failed ? "mail.list.failed.act" : "mail.toast.undo"
        }
    }

    private static func plural(_ count: Int) -> String {
        count == 1 ? ".one" : ".other"
    }

    public var name: String? {
        switch self {
        case .contactSaved(let name), .contactExists(let name), .projectSaved(let name), .attachmentCopied(let name),
             .unsubscribed(let name): name
        default: nil
        }
    }

    public var date: Date? {
        if case .planned(let date) = self { return date }
        return nil
    }

    public var count: Int? {
        switch self {
        case .bulkRead(let count, _), .bulkArchived(let count), .bulkTrashed(let count): count
        default: nil
        }
    }
}

public struct Toast: Equatable, Sendable {
    public let serial: Int
    public let kind: ToastKind
    public let undoable: Bool
    public var lasts: Duration?
}

enum HeadState: Equatable, Sendable {
    case empty
    case reading
    case draft
    case confirm
    case fanned
}
