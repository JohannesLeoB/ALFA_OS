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
    case signatureCollapsed = "mail.card.signatureCollapsed"
    case recipientsExpanded = "mail.card.recipientsExpanded"
    case actionFailed = "mail.card.actionFailed"
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
        case unread, starred, selected, hasAttachments, threadCount

        public var key: String {
            switch self {
            case .unread: "mail.row.unread"
            case .starred: "mail.row.starred"
            case .selected: "mail.row.selected"
            case .hasAttachments: "mail.row.hasAttachments"
            case .threadCount: "mail.row.threadCount"
            }
        }
    }

    public var kind: Kind {
        switch self {
        case .unread: .unread
        case .starred: .starred
        case .selected: .selected
        case .hasAttachments: .hasAttachments
        case .threadCount: .threadCount
        }
    }

    public var key: String { kind.key }
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
        case idle, edited, saving, saved, sending, sent, sendBlockedNoSubject, sendBlockedNoRecipient, sendFailed, queuedInOutbox

        public var key: String {
            switch self {
            case .idle: "mail.draft.idle"
            case .edited: "mail.draft.edited"
            case .saving: "mail.draft.saving"
            case .saved: "mail.draft.saved"
            case .sending: "mail.draft.sending"
            case .sent: "mail.draft.sent"
            case .sendBlockedNoSubject: "mail.draft.sendBlocked.noSubject"
            case .sendBlockedNoRecipient: "mail.draft.sendBlocked.noRecipient"
            case .sendFailed: "mail.draft.sendFailed"
            case .queuedInOutbox: "mail.draft.queuedInOutbox"
            }
        }
    }

    public var kind: Kind {
        switch self {
        case .idle: .idle
        case .edited: .edited
        case .saving: .saving
        case .saved: .saved
        case .sending: .sending
        case .sent: .sent
        case .sendBlocked(.noSubject): .sendBlockedNoSubject
        case .sendBlocked(.noRecipient): .sendBlockedNoRecipient
        case .sendFailed: .sendFailed
        case .queuedInOutbox: .queuedInOutbox
        }
    }

    public var key: String { kind.key }
}
