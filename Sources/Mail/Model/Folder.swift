import Foundation
import Shell

public enum FolderRole: String, Sendable, CaseIterable {
    case inbox
    case sent
    case drafts
    case trash
    case spam
    case archive
    case starred
    case outbox
    case all
    case other

    public var nameKey: String { self == .outbox ? "mail.folder.outbox" : "mail.role." + rawValue }
}

public struct Folder: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var role: FolderRole

    public static let outboxID = "local:outbox"

    public init(id: String, name: String, role: FolderRole = .other) {
        self.id = id
        self.name = name
        self.role = role
    }
}

public struct FolderEntry: Identifiable, Equatable, Sendable {
    public var id: String { folder.id }
    public let folder: Folder
    public let glyph: Icon
    public let count: Int
    public let selected: Bool
    public let attention: Bool
}

public struct FolderName: Equatable, Sendable {
    public let key: String?
    public let text: String
}

public enum EmptyKind: Equatable, Sendable {
    case loading
    case notConnected
    case failed(lastLoaded: Date?)
    case noResults(query: String, folder: FolderName)
    case noFilterMatch
    case empty(folder: FolderName)
}

public enum FolderTitle {
    public static func text(_ name: FolderName, localized: (String) -> String) -> String {
        name.key.map(localized) ?? name.text
    }
}
