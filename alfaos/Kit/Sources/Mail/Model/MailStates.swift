import Foundation
import Hub
import enum MykilosServices.MailFlag
import struct MykilosServices.MailMessageSummary

public enum MailFilter: Equatable, Sendable, CaseIterable {
    case all
    case unread
    case attachments

    func matches(_ summary: MailMessageSummary) -> Bool {
        switch self {
        case .all: true
        case .unread: !summary.flags.contains(.seen)
        case .attachments: summary.attachmentCount > 0
        }
    }
}

public enum MailListState: Equatable, Sendable {
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

public enum MailRowState: Equatable, Sendable {
    case unread
    case starred
    case selected
    case hasAttachments
    case threadCount(Int)
}

public struct MailRow: Identifiable, Equatable, Sendable {
    public var id: String { summary.id }
    public let summary: MailMessageSummary
    public let selected: Bool
    public let threadCount: Int

    public var unread: Bool { !summary.flags.contains(.seen) }
    public var starred: Bool { summary.flags.contains(.flagged) }
    public var hasAttachments: Bool { summary.attachmentCount > 0 }

    public var states: [MailRowState] {
        var result: [MailRowState] = []
        if unread { result.append(.unread) }
        if starred { result.append(.starred) }
        if selected { result.append(.selected) }
        if hasAttachments { result.append(.hasAttachments) }
        if threadCount > 1 { result.append(.threadCount(threadCount)) }
        return result
    }
}

public enum MailCardContent: Equatable, Sendable {
    case bodyLoading
    case text(String)
    case html(String, inlineImages: [String: String])
    case conversation(Int)
    case draftNotice
}

public struct ReadingCard: Identifiable, Equatable, Sendable {
    public var id: String { summary.id }
    public let inlet: Inlet.ID
    public var summary: MailMessageSummary
    public var content: MailCardContent
    public var remoteImagesAllowed = false
    public var quoteCollapsed = true
    public var signatureCollapsed = true
    public var recipientsExpanded = false

    public var remoteImagesBlocked: Bool {
        if case .html = content { return !remoteImagesAllowed }
        return false
    }
}

public enum SendBlockReason: Equatable, Sendable {
    case noSubject
    case noRecipient
}

public enum MailDraftState: Equatable, Sendable {
    case idle
    case edited
    case saving
    case saved(Date)
    case sending
    case sent
    case sendBlocked(SendBlockReason)
    case sendFailed(Hint)
    case queuedInOutbox
}
