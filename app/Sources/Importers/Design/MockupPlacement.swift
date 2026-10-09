import ALFAcolorCore
import BoardModel
import Foundation

/// Places a mockup delivery on the active space: frames in a row, pieces relative to their frame, as one undo step.
@MainActor
public enum MockupPlacement {
    public static let undoKey = "undo.mockup.import"
    /// Space between the frames, and between the old board and the new frames.
    static let gap = 80.0

    /// Returns false when there is no active space or nothing to place.
    @discardableResult
    public static func place(_ delivery: MockupDelivery, in store: BoardStore) throws -> Bool {
        guard let space = store.activeSpace else { return false }
        guard !delivery.frames.isEmpty || !delivery.pieces.isEmpty else { return false }
        let layerID = defaultLayer(of: space)
        let existingRight = space.items.map(\.rect.maxX).max() ?? 0
        var cursor = existingRight > 0 ? existingRight + 2 * gap : 0

        var items: [Item] = []
        var frameOrigin: [String: Double] = [:]
        for frame in delivery.frames {
            frameOrigin[frame.id] = cursor
            items.append(Item(title: frame.title, content: .frame(deviceID: nil, gridID: nil),
                              rect: Rect(x: cursor, y: 0, w: frame.width, h: frame.height), z: 0, layerID: layerID))
            cursor += frame.width + gap
        }
        let sheetX = cursor
        for (index, piece) in delivery.pieces.enumerated() {
            let originX = piece.frame.flatMap { frameOrigin[$0] } ?? sheetX
            let content = try boardContent(piece.content, in: store)
            items.append(Item(title: piece.title, content: content,
                              rect: Rect(x: originX + piece.x, y: piece.y, w: piece.width, h: piece.height),
                              z: index + 1, layerID: layer(piece.layer, in: space, fallback: layerID),
                              source: piece.source))
        }
        return try store.perform(.batch([.insert(items)], nameKey: undoKey))
    }

    private static func boardContent(_ content: MockupDelivery.Piece.Content, in store: BoardStore) throws -> Content {
        switch content {
        case .code(let language, let files, let previewWidth):
            return .code(language: CodeLanguage(rawValue: language) ?? .other, files: files, previewWidth: previewWidth)
        case .image(let bytes, let fileExtension):
            return .image(assetID: store.addAsset(bytes, fileExtension: fileExtension), crop: nil, fit: nil)
        case .note(let text):
            return .note(text: text)
        case .text(let text, let style):
            return .text(text: text, style: style)
        case .swatch(let hex):
            return .swatch(hex: hex, name: nil)
        case .link(let url, let note):
            return .link(url: url, note: note)
        }
    }

    /// The layer of the package when the space has it, else the first one that is visible and not locked.
    private static func layer(_ wanted: String?, in space: Space, fallback: String) -> String {
        if let wanted, space.layers.contains(where: { $0.id == wanted }) { return wanted }
        return fallback
    }

    private static func defaultLayer(of space: Space) -> String {
        space.layers.first { $0.visible && !$0.locked }?.id ?? "standard"
    }
}
