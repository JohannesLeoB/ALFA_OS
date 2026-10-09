import Foundation

/// The kind of an item without its content. The inspector, the library and the filters use it.
public enum ItemKind: String, Codable, Hashable, Sendable, CaseIterable {
    case code, frame, group, image, link, note, shape, swatch, text

    public init(_ content: Content) {
        switch content {
        case .code: self = .code
        case .frame: self = .frame
        case .group: self = .group
        case .image: self = .image
        case .link: self = .link
        case .note: self = .note
        case .shape: self = .shape
        case .swatch: self = .swatch
        case .text: self = .text
        }
    }

    /// The key of the name in the string catalog, for example "item.kind.note".
    public var nameKey: String { "item.kind.\(rawValue)" }
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
