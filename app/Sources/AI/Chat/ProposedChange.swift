import Foundation

/// One change that the assistant proposes. It is data only: nothing is applied until the user accepts it.
/// Item IDs are the IDs of the document; the app maps each case to its commands when the user accepts.
public enum ProposedChange: Sendable, Equatable {
    /// A note on an item.
    case note(item: String, text: String)
    /// Tags on an item, added to the tags it has.
    case tags(item: String, tags: [String])
    /// A new code card with its files.
    case codeCard(title: String, language: String, files: [String: String])
    /// A new version of an existing code card; the original stays.
    case codeVersion(item: String, language: String, files: [String: String])
    /// New colour fields. A name is optional.
    case swatches([Swatch])
    /// A name for each unnamed colour token.
    case tokenNames([TokenName])
    /// A note card on the canvas.
    case noteCard(text: String)
    /// Removes items, in the room or in the whole collection.
    case delete(items: [String], scope: ChangeScope)
    /// Moves items by a distance in points.
    case move(items: [String], dx: Double, dy: Double)
    /// A link item with its address and title.
    case link(url: String, title: String)
    /// A download of a web address into the document or into a folder on the Mac.
    case download(url: String, target: DownloadTarget)
    /// New values for the design contract tokens.
    case designTokens([DesignTokenValue])
    /// A tip. A note tip is attached to an item; the other tips only show in the chat or the lab.
    case tip(kind: TipKind, text: String, item: String?)

    /// The items that the change refers to. A change whose items are gone is stale.
    public var referencedItems: [String] {
        switch self {
        case let .note(item, _), let .tags(item, _), let .codeVersion(item, _, _):
            [item]
        case let .delete(items, _), let .move(items, _, _):
            items
        case let .tip(kind, _, item):
            kind == .note ? (item.map { [$0] } ?? []) : []
        case let .tokenNames(names):
            names.map(\.id)
        case .codeCard, .swatches, .noteCard, .link, .download, .designTokens:
            []
        }
    }
}

/// A new colour field with its name and its colour as `#RRGGBB`.
public struct Swatch: Sendable, Equatable {
    public var name: String?
    public var hex: String

    public init(name: String?, hex: String) {
        self.name = name
        self.hex = hex
    }
}

/// A name for one unnamed token of the document.
public struct TokenName: Sendable, Equatable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A new value for one token of the design contract.
public struct DesignTokenValue: Sendable, Equatable {
    public var name: String
    public var hex: String

    public init(name: String, hex: String) {
        self.name = name
        self.hex = hex
    }
}

/// Where a removal reaches: the room of the item, or every room of the document.
public enum ChangeScope: String, Sendable, Equatable {
    case room
    case collection
}

/// Where a download goes: into the document as pieces, or into a folder on the Mac.
public enum DownloadTarget: String, Sendable, Equatable {
    case document
    case folder
}

/// The kind of a tip. A chat tip shows only in the chat; a lab tip shows in the lab; a note tip is a note on an item.
public enum TipKind: String, Sendable, Equatable {
    case chat
    case lab
    case note
}
