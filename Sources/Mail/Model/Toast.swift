public enum ToastKind: Equatable, Sendable {
    case archived
    case trashed
    case inTrash
    case purged
    case draftSaved
    case recipientMissing
    case addressCopied
    case projectSaved
    case pdfSaved
    case contactSaved(String)
    case contactExists(String)
    case contactRemoved
    case bulkRead(count: Int, read: Bool)
    case bulkArchived(count: Int)
    case bulkTrashed(count: Int)

    public var key: String {
        switch self {
        case .archived: "mail.toast.archived"
        case .trashed: "mail.toast.trashed"
        case .inTrash: "mail.toast.inTrash"
        case .purged: "mail.toast.purged"
        case .draftSaved: "mail.toast.draftSaved"
        case .recipientMissing: "mail.toast.recipientMissing"
        case .addressCopied: "mail.toast.addressCopied"
        case .projectSaved: "mail.toast.projectSaved"
        case .pdfSaved: "mail.toast.pdfSaved"
        case .contactSaved: "mail.toast.contactSaved"
        case .contactExists: "mail.toast.contactExists"
        case .contactRemoved: "mail.toast.contactRemoved"
        case .bulkRead(let count, let read): "mail.toast.bulkRead." + (read ? "read" : "unread") + Self.plural(count)
        case .bulkArchived(let count): "mail.toast.bulkArchived" + Self.plural(count)
        case .bulkTrashed(let count): "mail.toast.bulkTrashed" + Self.plural(count)
        }
    }

    private static func plural(_ count: Int) -> String {
        count == 1 ? ".one" : ".other"
    }

    public var name: String? {
        switch self {
        case .contactSaved(let name), .contactExists(let name): name
        default: nil
        }
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
