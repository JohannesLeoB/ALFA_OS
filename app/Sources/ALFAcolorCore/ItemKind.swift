import Foundation

/// The kind of an item without its content. Used by the library to filter and to list kinds.
public enum ItemKind: String, Codable, Hashable, Sendable, CaseIterable {
    case image, note, text, shape, swatch, link, code, frame, group

    public init(content: Content) {
        switch content {
        case .code: self = .code
        case .image: self = .image
        case .note: self = .note
        case .swatch: self = .swatch
        case .link: self = .link
        case .frame: self = .frame
        case .group: self = .group
        case .shape: self = .shape
        case .text: self = .text
        }
    }
}

/// An item of a document, found by its room and its ID. Item IDs are unique inside a room only.
public struct ItemRef: Codable, Hashable, Sendable {
    public var spaceID: String
    public var itemID: ItemID

    public init(spaceID: String, itemID: ItemID) {
        self.spaceID = spaceID
        self.itemID = itemID
    }
}
