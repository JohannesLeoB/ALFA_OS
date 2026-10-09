import Foundation
import ALFAcolorCore
import BoardModel

public enum ImportError: LocalizedError, Equatable, Sendable {
    /// Every layer of the space is locked.
    case noEditableLayer

    public var errorDescription: String? {
        switch self {
        case .noEditableLayer: String(localized: "import.error.noEditableLayer")
        }
    }
}

/// Puts pieces on the board. All pieces of one paste or drop are one undo step.
@MainActor
public struct BoardImporter {
    public let store: BoardStore

    public init(store: BoardStore) { self.store = store }

    /// Adds the pieces to the active space, around a point of the board, on top of the first layer that is not locked.
    /// Image bytes go into the document. They are no undo step by themselves and stay in the document when the paste is undone.
    /// The new items are selected. Returns their IDs.
    @discardableResult
    public func insert(_ pieces: [Piece], centerX: Double, centerY: Double, headerHeight: Double, nameKey: String) throws -> [ItemID] {
        guard !pieces.isEmpty else { return [] }
        guard let space = store.activeSpace else { throw CommandError.noActiveSpace }
        guard let layer = space.layers.first(where: { !$0.locked }) else { throw ImportError.noEditableLayer }

        let rects = PieceLayout(headerHeight: headerHeight).rects(for: pieces, centerX: centerX, centerY: centerY)
        var top = space.items.filter { $0.layerID == layer.id }.map(\.z).max() ?? -1
        var items: [Item] = []
        for (piece, rect) in zip(pieces, rects) {
            let content: Content
            switch piece.body {
            case .image(let data, let fileExtension, _):
                content = .image(assetID: store.addAsset(data, fileExtension: fileExtension), crop: nil)
            case .content(let value):
                content = value
            }
            top += 1
            var item = Item(title: piece.title, content: content, rect: rect, z: top, layerID: layer.id, source: piece.source)
            item.tags = piece.tags
            items.append(item)
        }
        try store.perform(.batch([.insert(items)], nameKey: nameKey))
        return items.map(\.id)
    }
}
