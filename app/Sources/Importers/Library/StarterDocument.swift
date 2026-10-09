import ALFAcolorCore
import Document
import Foundation

/// The starter document "Bausteine": one space per room, one code card per upstream component.
/// The board is built from the source files in the resources, so the file is generated and not typed by hand.
public enum StarterDocument {
    public static let title = "Bausteine"
    /// Fixed, so that the generated file is the same on every run.
    public static let documentID = UUID(uuidString: "7BB94D1A-55E8-4EB4-84B2-F0B5C5D81557")!
    /// 2026-10-09 00:00 UTC, the day the cards were taken in.
    public static let date = Date(timeIntervalSince1970: 1_791_504_000)

    /// Card size on the canvas, in points, and the gap between cards.
    static let cardWidth = 720.0
    static let cardHeight = 480.0
    static let gap = 40.0
    static let columns = 3

    /// Shared runtime files, in run order. They come before the extra runtime files of a card.
    static let sharedRuntime = ["runtime/shims.tsx", "runtime/useClickOutside.tsx", "runtime/usePreventScroll.tsx"]

    /// The board, read from the source folder (ALFAcolor/App/Resources/Starter/source).
    public static func board(sourceRoot: URL) throws -> Board {
        let spaces = try StarterRoom.allCases.map { room -> Space in
            let cards = cards(in: room)
            let items = try cards.enumerated().map { index, card in
                try item(card, room: room, index: index, sourceRoot: sourceRoot)
            }
            return Space(id: room.spaceID, name: room.name, items: items)
        }
        return Board(title: title, spaces: spaces, documentID: documentID, createdAt: date)
    }

    /// The cards of a room, in the order of the catalog.
    public static func cards(in room: StarterRoom) -> [StarterCard] {
        switch room {
        case .movement: StarterCatalog.motion
        }
    }

    /// The origin of the cards of a room.
    public static func origin(of room: StarterRoom) -> StarterOrigin {
        switch room {
        case .movement: StarterCatalog.motionOrigin
        }
    }

    /// The source files of a card in run order: shared runtime, extra runtime, the component and its demo.
    static func sourcePaths(for card: StarterCard, room: StarterRoom) -> [String] {
        var paths = sharedRuntime + card.extraRuntime
        paths.append("\(room.folder)/\(card.name).tsx")
        if card.demo != nil {
            paths.append("\(room.folder)/demo/\(card.name).tsx")
        }
        return paths
    }

    /// One code card: the page in `index.html`, placed in a grid with three columns.
    static func item(_ card: StarterCard, room: StarterRoom, index: Int, sourceRoot: URL) throws -> Item {
        let sources = try sourcePaths(for: card, room: room).map { try read($0, under: sourceRoot) }
        let html = CardPage.html(sources: sources, render: card.render)
        let origin = origin(of: room)
        var file = "components/core/\(card.name).tsx"
        if let demo = card.demo {
            file += ", app/docs/\(card.name)/\(demo)"
        }
        let source = Source(url: URL(string: "\(origin.repository)/blob/main/components/core/\(card.name).tsx"),
                            file: file, license: origin.licence, via: "starter", importedAt: date)
        let column = Double(index % columns)
        let row = Double(index / columns)
        let rect = Rect(x: gap + column * (cardWidth + gap), y: gap + row * (cardHeight + gap),
                        w: cardWidth, h: cardHeight)
        return Item(id: ItemID("starter-\(card.name)"), title: card.title,
                    content: .code(language: .html, files: ["index.html": html], previewWidth: cardWidth),
                    rect: rect, source: source)
    }

    /// The text of a source file under the source folder.
    static func read(_ path: String, under root: URL) throws -> String {
        let url = root.appending(path: path, directoryHint: .notDirectory)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw StarterError.unreadable(path)
        }
        return text
    }

    /// Writes the starter document as a package folder, for example to the resources.
    @discardableResult
    public static func writePackage(sourceRoot: URL, to url: URL) throws -> DocumentPackage.WriteReport {
        let document = ALFAcolorDocument(board: try board(sourceRoot: sourceRoot))
        return try DocumentPackage.write(document, to: url, appVersion: "0.1.0")
    }
}
