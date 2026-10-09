import Foundation
import ALFAcolorCore

/// The versions of all code cards of a document, by item. Each list is oldest first.
/// The current code of a card is not a version: it stays on the board. A version is an earlier state.
public struct CardVersions: Equatable, Sendable {
    /// Most versions that one card keeps. The oldest go first.
    public static let limit = 50
    /// Largest size of one version in bytes (file names and texts). A larger version is not kept.
    public static let sizeLimit = 512 * 1024

    private var byItem: [ItemID: [CardVersion]] = [:]

    public init() {}

    /// The versions of a card, oldest first. Empty for a card without versions.
    public func versions(of item: ItemID) -> [CardVersion] {
        byItem[item] ?? []
    }

    /// The cards that have at least one version.
    public var itemsWithVersions: Set<ItemID> {
        Set(byItem.filter { !$0.value.isEmpty }.keys)
    }

    /// True when the size of a version is within the limit.
    public static func accepts(_ version: CardVersion) -> Bool {
        version.size <= sizeLimit
    }

    /// Keeps a version as the newest of a card. The oldest go when the card is over the limit.
    /// Returns false and changes nothing when the version is too large, or when it has the same code as the newest version.
    @discardableResult
    public mutating func append(_ version: CardVersion, to item: ItemID) -> Bool {
        guard Self.accepts(version) else { return false }
        var list = byItem[item] ?? []
        if let newest = list.last, newest.hasSameCode(as: version) { return false }
        list.append(version)
        if list.count > Self.limit { list.removeFirst(list.count - Self.limit) }
        byItem[item] = list
        return true
    }

    /// Removes the version at `index`, where 0 is the oldest. Returns false when there is no such version.
    @discardableResult
    public mutating func remove(at index: Int, of item: ItemID) -> Bool {
        guard var list = byItem[item], list.indices.contains(index) else { return false }
        list.remove(at: index)
        byItem[item] = list.isEmpty ? nil : list
        return true
    }

    /// Takes the versions of a card as they were read from a file. Keeps the newest `limit` versions and
    /// leaves out those over the size limit. Returns how many versions were left out.
    @discardableResult
    mutating func load(_ versions: [CardVersion], for item: ItemID) -> Int {
        let fitting = versions.filter(Self.accepts)
        let kept = Array(fitting.suffix(Self.limit))
        byItem[item] = kept.isEmpty ? nil : kept
        return versions.count - kept.count
    }

    /// Drops the versions of cards that are not in `items`. Used when the document is written.
    func restricted(to items: Set<ItemID>) -> CardVersions {
        var copy = self
        copy.byItem = byItem.filter { items.contains($0.key) && !$0.value.isEmpty }
        return copy
    }
}
