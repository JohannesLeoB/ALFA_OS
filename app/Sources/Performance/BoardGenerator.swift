import Foundation
import ALFAcolorCore
import Document

/// Builds one large test board: mixed items on a grid, and code cards. The same arguments give the same document.
/// Nothing is written to disk here; a test that needs files writes them to a temporary folder.
public enum BoardGenerator {
    public static let spaceID = "load"
    /// Distinct image contents. Image items share them, as placed copies of one image do.
    public static let imageVariants = 40
    /// Grid pitch in board points. Each item gets one cell, with a random offset inside it.
    public static let cellSize = 160.0
    /// Fixed identity, so that equal arguments give equal documents.
    static let documentID = UUID(uuidString: "6F1E2C3A-0000-4000-8000-000000000001") ?? UUID()
    static let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// A document with one space. `items` mixed items (images, notes, shapes, texts, swatches, links)
    /// and `codeCards` code cards are spread evenly among them. Each image is 256 bytes.
    public static func document(items: Int, codeCards: Int = 100, seed: UInt64 = 1) -> ALFAcolorDocument {
        var random = SeededRandom(seed: seed)
        var assets = AssetStore()
        var assetIDs: [String] = []
        for variant in 0..<imageVariants {
            assetIDs.append(assets.add(imageBytes(variant), fileExtension: "png"))
        }
        let total = max(items, 0) + max(codeCards, 0)
        let columns = max(Int(Double(total).squareRoot().rounded(.up)), 1)
        // Code cards are spread evenly over the board, one every `stride` positions.
        let stride = codeCards > 0 ? max(total / codeCards, 1) : Int.max
        var stack: [Item] = []
        stack.reserveCapacity(total)
        for index in 0..<total {
            let column = index % columns, row = index / columns
            let x = Double(column) * cellSize + random.fraction(of: cellSize / 3)
            let y = Double(row) * cellSize + random.fraction(of: cellSize / 3)
            let isCode = codeCards > 0 && index % stride == 0 && index / stride < codeCards
            let item: Item
            if isCode {
                let rect = Rect(x: x, y: y, w: 320, h: 240)
                let source = "struct Card\(index): View { var body: some View { Text(\"\(index)\") } }"
                item = Item(id: ItemID("i\(index)"), title: "Code \(index)",
                            content: .code(language: .swiftui, files: ["Card.swift": source], previewWidth: nil),
                            rect: rect, z: index, layerID: "standard")
            } else {
                item = mixedItem(index: index, x: x, y: y, assetIDs: assetIDs, random: &random)
            }
            stack.append(item)
        }
        let space = Space(id: spaceID, name: "Load", layers: [Layer(id: "standard", name: "Standard")], items: stack)
        let board = Board(title: "Load", spaces: [space], documentID: documentID, createdAt: createdAt)
        return ALFAcolorDocument(board: board, assets: assets)
    }

    /// One item of the mix. The kind is chosen by weight: images 40, notes 25, shapes 15, texts 10, swatches 10 (in percent).
    static func mixedItem(index: Int, x: Double, y: Double, assetIDs: [String], random: inout SeededRandom) -> Item {
        let roll = random.below(100)
        let id = ItemID("i\(index)")
        switch roll {
        case 0..<40:
            let rect = Rect(x: x, y: y, w: 120, h: 90)
            let asset = assetIDs[random.below(assetIDs.count)]
            return Item(id: id, title: "Image \(index)", content: .image(assetID: asset, crop: nil), rect: rect, z: index, layerID: "standard")
        case 40..<65:
            let rect = Rect(x: x, y: y, w: 140, h: 80)
            return Item(id: id, title: "Note \(index)", content: .note(text: "Note \(index)"), rect: rect, z: index, layerID: "standard")
        case 65..<80:
            let kinds = ShapeKind.allCases
            let rect = Rect(x: x, y: y, w: 60, h: 60)
            let style = ShapeStyle(fill: color(random.next()))
            return Item(id: id, title: "Shape \(index)", content: .shape(kind: kinds[random.below(kinds.count)], style: style), rect: rect, z: index, layerID: "standard")
        case 80..<90:
            let rect = Rect(x: x, y: y, w: 120, h: 30)
            return Item(id: id, title: "Text \(index)", content: .text(text: "Text \(index)", style: index % 2 == 0 ? "heading" : "body"), rect: rect, z: index, layerID: "standard")
        default:
            let rect = Rect(x: x, y: y, w: 24, h: 24)
            return Item(id: id, title: "Swatch \(index)", content: .swatch(hex: color(random.next()), name: nil), rect: rect, z: index, layerID: "standard")
        }
    }

    /// 256 bytes that differ per variant. They are not a real image; only their size and hash matter here.
    static func imageBytes(_ variant: Int) -> Data {
        Data((0..<256).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ variant &* 7) })
    }

    static func color(_ value: UInt64) -> String {
        String(format: "#%06X", Int(value % 0x100_0000))
    }
}
