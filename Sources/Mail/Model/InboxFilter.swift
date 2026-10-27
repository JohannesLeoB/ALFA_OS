import Foundation
import Hub

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
