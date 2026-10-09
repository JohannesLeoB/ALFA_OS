import Foundation

/// A colour for the filter: items with a colour within `distance` of it match. The distance is a CIE76 delta E
/// in the Lab space. Below about 2.3 the difference is hardly visible; 10 still counts as a related shade.
public struct ColorNear: Codable, Hashable, Sendable {
    public var hex: String
    public var distance: Double

    public init(hex: String, distance: Double = 10) {
        self.hex = hex
        self.distance = distance
    }
}

/// The conditions of a library search. Every condition that is set must hold; an empty condition does not restrict.
/// A folder with a filter keeps this value, so it must stay plain data.
public struct LibraryFilter: Codable, Hashable, Sendable {
    /// Words that must all occur in the searchable text: title, note, text, link address and note, code.
    public var text: String
    /// Kinds that are allowed. Empty allows every kind.
    public var kinds: Set<ItemKind>
    /// Tags that must all be on the item. Compared without case.
    public var tags: Set<String>
    /// The way the item came in, as `Source.via` says ("paste", "file", "bookmark" …). Compared without case.
    public var via: String?
    /// The host of the item's address: the source address, or the link address. Compared without case.
    public var host: String?
    /// A colour that one of the item's colours must be close to.
    public var color: ColorNear?
    /// The first day of the import date, inclusive. Items without a source have no import date and do not match.
    public var importedFrom: Date?
    /// The last day of the import date, inclusive.
    public var importedUntil: Date?
    /// Part of the licence text of the source, without case. Items without a source do not match.
    public var license: String?

    public init(text: String = "", kinds: Set<ItemKind> = [], tags: Set<String> = [], via: String? = nil, host: String? = nil,
                color: ColorNear? = nil, importedFrom: Date? = nil, importedUntil: Date? = nil, license: String? = nil) {
        self.text = text
        self.kinds = kinds
        self.tags = tags
        self.via = via
        self.host = host
        self.color = color
        self.importedFrom = importedFrom
        self.importedUntil = importedUntil
        self.license = license
    }

    /// True when no condition is set: every item matches.
    public var isEmpty: Bool { self == LibraryFilter() }
}
