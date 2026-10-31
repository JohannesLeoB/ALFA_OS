import Foundation

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
        case .contactSaved(let name), .contactExists(let name), .projectSaved(let name), .attachmentCopied(let name): name
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
}
