import Foundation

public enum MailKey {
    public static let signInExpiredHint = "hint.signin.expired"
    public static let offlineHint = MailHintKey.offline
    public static let notConnectedHint = "hint.mail.notConnected"
    public static let noInletHint = "hint.mail.noInlet"
    public static let capabilityMissingHint = "hint.mail.capabilityMissing"
}

extension MailListState {
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

extension MailRowState {
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

extension MailCardContent {
    public var key: String? {
        switch self {
        case .bodyLoading: "mail.card.bodyLoading"
        case .text, .html: nil
        case .conversation: "mail.card.conversation"
        case .draftNotice: "mail.card.draftNotice"
        }
    }
}

extension ReadingCard {
    public static let remoteImagesBlockedKey = "mail.card.remoteImagesBlocked"
    public static let quoteCollapsedKey = "mail.card.quoteCollapsed"
    public static let signatureCollapsedKey = "mail.card.signatureCollapsed"
    public static let recipientsExpandedKey = "mail.card.recipientsExpanded"
    public static let actionFailedKey = "mail.card.actionFailed"
}

extension MailDraftState {
    public var key: String {
        switch self {
        case .idle: "mail.draft.idle"
        case .edited: "mail.draft.edited"
        case .saving: "mail.draft.saving"
        case .saved: "mail.draft.saved"
        case .sending: "mail.draft.sending"
        case .sent: "mail.draft.sent"
        case .sendBlocked(.noSubject): "mail.draft.sendBlocked.noSubject"
        case .sendBlocked(.noRecipient): "mail.draft.sendBlocked.noRecipient"
        case .sendFailed: "mail.draft.sendFailed"
        case .queuedInOutbox: "mail.draft.queuedInOutbox"
        }
    }
}
