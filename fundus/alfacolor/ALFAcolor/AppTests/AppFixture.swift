import ALFAcolorCore
import Foundation
import BoardModel
import CodePlayer
import CoreGraphics
import Document
import Library
import Tokens

/// A document for the layout tests: one room with a code card that has a source and one kept version,
/// and a token set with two colour fields, one with a very long name.
@MainActor
enum AppFixture {
    /// The session with the code card selected, or without any selection.
    /// `worst` fills every field with the longest text and the biggest numbers a document can hold in practice.
    static func session(selectCard: Bool = true, worst: Bool = false) -> DocumentSession {
        let card = Item(
            title: "Hero section with a long title that has to be cut",
            content: .code(language: .html, files: ["index.html": "<p>hello</p>", "style.css": "p { color: red }"], previewWidth: nil),
            rect: worst ? Rect(x: 12_345_678, y: 87_654_321, w: 23_456_789, h: 19_876_543) : Rect(x: 0, y: 0, w: 320, h: 200),
            source: Source(url: URL(string: "https://example.com/a/very/long/path/to/the/original/page"),
                           file: worst ? "MAIL \u{00B7} VOLLBILD with a very long file name that never ends.dc.html" : nil,
                           license: "CC BY 4.0", via: worst ? "bookmark-with-a-long-way-in" : "paste")
        )
        let space = Space(id: "start", name: "Start", layers: [Layer(id: "standard", name: "Standard")], items: [card])
        let colors = TokenSet(name: ColorFields.setName, tokens: [
            Token(["color", "Brand primary"], .color(RGB(r: 0.9, g: 0.3, b: 0.2))),
            Token(["color", "A colour field with a very long name"], .color(RGB(r: 0.1, g: 0.2, b: 0.3))),
        ])
        let session = DocumentSession(document: ALFAcolorDocument(board: Board(title: "Test", spaces: [space]), tokenSets: [colors]), report: nil)
        _ = try? session.store.keepVersion(of: card.id)
        if worst {
            for name in ["A folder with a very long name that cannot fit", "Second folder"] {
                _ = try? session.store.changeBoard(nameKey: "undo.folder.add") { board in
                    try FolderEdit.add(Folder(id: name, name: name, rule: .fixed([])), to: &board.folders)
                }
            }
        }
        if selectCard { session.store.select([card.id]) }
        return session
    }

    /// Puts a large still image of the kept version into the cache of the stills, as the app does after a card was
    /// shown. The version row then shows a preview, and the preview has the pixel size of the card, not of the column.
    static func cacheStill(of session: DocumentSession) async {
        guard let id = session.store.selectedItems.first?.id,
              let version = session.store.document.versions.versions(of: id).first else { return }
        let card = CodeCard(language: version.language, files: version.files)
        _ = try? await CodeStills.shared.still(for: card, width: CodeCardLayout.pageWidth(previewWidth: nil), renderer: WideRenderer())
    }
}

/// A renderer that draws a plain still of 1280 by 800 pixels.
@MainActor
private struct WideRenderer: CardRenderer {
    func canRender(_ card: CodeCard) -> Bool { true }
    func makeLive(_ card: CodeCard) async throws -> LiveCard { throw CardRendererError.noLiveForm }
    func snapshot(_ card: CodeCard, width: Double) async throws -> CGImage {
        let context = CGContext(data: nil, width: 1280, height: 800, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1280, height: 800))
        return context.makeImage()!
    }
}
