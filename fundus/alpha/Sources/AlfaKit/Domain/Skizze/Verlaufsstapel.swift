import Foundation

public struct Verlaufsstapel<Status: Equatable> {
    private var vergangenheit: [Status] = []
    private var zukunft: [Status] = []
    public private(set) var aktuell: Status
    public let maxTiefe: Int

    public init(_ start: Status, maxTiefe: Int = 500) {
        self.aktuell = start
        self.maxTiefe = max(1, maxTiefe)
    }

    public var kannZurueck: Bool { !vergangenheit.isEmpty }
    public var kannVor: Bool { !zukunft.isEmpty }
    public var depth: Int { vergangenheit.count }

    public mutating func setze(_ neu: Status) {
        guard neu != aktuell else { return }
        vergangenheit.append(aktuell)
        if vergangenheit.count > maxTiefe { vergangenheit.removeFirst() }
        aktuell = neu
        zukunft.removeAll()
    }

    @discardableResult
    public mutating func zurueck() -> Bool {
        guard let vorher = vergangenheit.popLast() else { return false }
        zukunft.append(aktuell)
        aktuell = vorher
        return true
    }

    @discardableResult
    public mutating func vor() -> Bool {
        guard let nachher = zukunft.popLast() else { return false }
        vergangenheit.append(aktuell)
        aktuell = nachher
        return true
    }
}

public struct SkizzenSnapshot: Equatable, Sendable {
    public var layers: [SkizzenLayer]
    public var slots: [MaterialSlot]

    public var images: [PlatziertesBild]

    public init(layers: [SkizzenLayer], slots: [MaterialSlot], images: [PlatziertesBild] = []) {
        self.layers = layers
        self.slots = slots
        self.images = images
    }
}
