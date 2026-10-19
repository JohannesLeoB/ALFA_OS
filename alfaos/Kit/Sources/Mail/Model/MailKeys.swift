import Foundation

public enum MailTextKey: String, CaseIterable, Sendable {
    case offline = "mail.hint.offline"
    case rejected = "mail.hint.rejected"
    case failed = "mail.hint.failed"
    case notConnected = "hint.mail.notConnected"
    case noInlet = "hint.mail.noInlet"
    case capabilityMissing = "hint.mail.capabilityMissing"
    case remoteImagesBlocked = "mail.card.remoteImagesBlocked"
    case quoteCollapsed = "mail.card.quoteCollapsed"
    case recipientsExpanded = "mail.card.recipientsExpanded"
}

extension MailListState {
    public enum Kind: CaseIterable, Sendable {
        case empty, emptySearch, loading, loadingMore, loaded, noFilterMatch, failed, notConnected, signInExpired, offline

        public var key: String? {
            switch self {
            case .empty: "mail.list.empty"
            case .emptySearch: "mail.list.emptySearch"
            case .loading: "mail.list.loading"
            case .loadingMore: "mail.list.loadingMore"
            case .loaded: nil
            case .noFilterMatch: "mail.list.noFilterMatch"
            case .failed: "mail.list.failed"
            case .notConnected: "mail.list.notConnected"
            case .signInExpired: "mail.list.signInExpired"
            case .offline: "mail.list.offline"
            }
        }
    }

    public var kind: Kind {
        switch self {
        case .empty: .empty
        case .emptySearch: .emptySearch
        case .loading: .loading
        case .loadingMore: .loadingMore
        case .loaded: .loaded
        case .noFilterMatch: .noFilterMatch
        case .failed: .failed
        case .notConnected: .notConnected
        case .signInExpired: .signInExpired
        case .offline: .offline
        }
    }

    public var key: String? { kind.key }
}

extension MailRowState {
    public enum Kind: CaseIterable, Sendable {
        case unread, starred, hasAttachments, threadCount

        public var key: String {
            switch self {
            case .unread: "mail.row.unread"
            case .starred: "mail.row.starred"
            case .hasAttachments: "mail.row.hasAttachments"
            case .threadCount: "mail.row.threadCount"
            }
        }
    }

    public var kind: Kind? {
        switch self {
        case .unread: .unread
        case .starred: .starred
        case .selected: nil
        case .hasAttachments: .hasAttachments
        case .threadCount: .threadCount
        }
    }

    public var key: String? { kind?.key }
}

extension MailCardContent {
    public enum Kind: CaseIterable, Sendable {
        case bodyLoading, text, html, conversation, draftNotice

        public var key: String? {
            switch self {
            case .bodyLoading: "mail.card.bodyLoading"
            case .text, .html: nil
            case .conversation: "mail.card.conversation"
            case .draftNotice: "mail.card.draftNotice"
            }
        }
    }

    public var kind: Kind {
        switch self {
        case .bodyLoading: .bodyLoading
        case .text: .text
        case .html: .html
        case .conversation: .conversation
        case .draftNotice: .draftNotice
        }
    }

    public var key: String? { kind.key }
}

extension MailDraftState {
    public enum Kind: CaseIterable, Sendable {
        case saved, sending, sendBlockedNoSubject, sendBlockedNoRecipient, sendFailed, queuedInOutbox

        public var key: String {
            switch self {
            case .saved: "mail.draft.saved"
            case .sending: "mail.draft.sending"
            case .sendBlockedNoSubject: "mail.draft.sendBlocked.noSubject"
            case .sendBlockedNoRecipient: "mail.draft.sendBlocked.noRecipient"
            case .sendFailed: "mail.draft.sendFailed"
            case .queuedInOutbox: "mail.draft.queuedInOutbox"
            }
        }
    }

    public var kind: Kind? {
        switch self {
        case .idle, .edited, .saving, .sent: nil
        case .saved: .saved
        case .sending: .sending
        case .sendBlocked(.noSubject): .sendBlockedNoSubject
        case .sendBlocked(.noRecipient): .sendBlockedNoRecipient
        case .sendFailed: .sendFailed
        case .queuedInOutbox: .queuedInOutbox
        }
    }

    public var key: String? { kind?.key }
}
