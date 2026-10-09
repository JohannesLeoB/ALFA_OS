import Foundation
import ALFAcolorCore
import Document
import Geometry
import Tokens

/// One piece on a sheet page, as the drawing needs it. The rect is relative to the frame, in points.
struct SheetPiece: Equatable, Sendable {
    let kind: ItemKind
    let title: String
    let rect: Rect
    /// Fill colour as hex, for swatches and filled shapes. nil otherwise.
    let fill: String?
    /// Name of a swatch as the user gave it. nil otherwise.
    let swatchName: String?
    /// Text of a note or a text item. nil otherwise.
    let text: String?
    /// Language of a code card. nil otherwise.
    let language: CodeLanguage?
    /// Bytes of an image. nil for other kinds, and for a foreign image: that one is only a link.
    let imageData: Data?
    /// Link and licence of a foreign image, as text for the sheet. nil for other pieces.
    let origin: String?
}

/// One colour of the legend: its hex value and the name of the token or swatch that has it.
struct SheetSwatch: Equatable, Sendable {
    let hex: String
    let name: String?
}

/// One page of the sheet: a frame with its pieces, or the free items when no frame holds them.
struct SheetPage: Equatable, Sendable {
    /// The title of the frame. nil on the free sheet.
    let title: String?
    /// The frame size in points, or the bounds of the free items measured from their top left corner.
    let size: Rect
    /// The names of the spaces the page comes from, separated by commas.
    let space: String
    /// The catalog key of the device name, nil without a device.
    let deviceKey: String?
    let pieces: [SheetPiece]
    /// At most `SheetPages.legendLimit` colours, in the order of the pieces.
    let legend: [SheetSwatch]
    /// Colours that do not fit into the legend.
    let legendOverflow: Int
    let isFreeSheet: Bool
}

/// Builds the pages of the sheet from a document and a scope. One page per frame, then one page for the free items.
/// Pure logic: the bytes of images are copied, nothing is drawn.
enum SheetPages {
    /// The most colours that the legend lists.
    static let legendLimit = 24

    static func make(document: ALFAcolorDocument, scope: ExchangeScope) throws -> [SheetPage] {
        let plan = try MockupPlan(document: document, scope: scope)
        var pages: [SheetPage] = []
        for frame in plan.frames {
            let placed = plan.placed.filter { $0.frame?.id == frame.id }
            var deviceID: String?
            if case .frame(let id, _, _, _, _) = frame.content { deviceID = id }
            let size = Rect(x: 0, y: 0, w: frame.rect.w, h: frame.rect.h)
            pages.append(page(for: placed, document: document, plan: plan, title: frame.title, size: size,
                              space: spaceName(holding: frame, in: document) ?? "",
                              deviceKey: deviceID.flatMap { Device.resolve($0)?.name }, isFree: false))
        }
        let free = plan.placed.filter { $0.frame == nil }
        if !free.isEmpty {
            let boxes = free.map { plan.position(of: $0) }
            let size = Rect(x: 0, y: 0, w: boxes.map(\.maxX).max() ?? 0, h: boxes.map(\.maxY).max() ?? 0)
            let spaces = Array(Set(free.compactMap { spaceName(holding: $0.item, in: document) })).sorted()
            pages.append(page(for: free, document: document, plan: plan, title: nil, size: size,
                              space: spaces.joined(separator: ", "), deviceKey: nil, isFree: true))
        }
        return pages
    }

    private static func page(for placed: [MockupPlan.Placed], document: ALFAcolorDocument, plan: MockupPlan,
                             title: String?, size: Rect, space: String, deviceKey: String?, isFree: Bool) -> SheetPage {
        let pieces = placed.map { piece(for: $0, document: document, plan: plan) }
        let colours = colourSwatches(in: pieces, document: document)
        return SheetPage(title: title, size: size, space: space, deviceKey: deviceKey, pieces: pieces,
                         legend: Array(colours.prefix(legendLimit)),
                         legendOverflow: max(0, colours.count - legendLimit), isFreeSheet: isFree)
    }

    private static func piece(for placed: MockupPlan.Placed, document: ALFAcolorDocument, plan: MockupPlan) -> SheetPiece {
        let item = placed.item
        var fill: String?
        var swatchName: String?
        var text: String?
        var language: CodeLanguage?
        var imageData: Data?
        var origin: String?
        switch item.content {
        case .swatch(let hex, let name):
            fill = hex
            swatchName = name
        case .shape(_, let style):
            fill = style.fill
        case .note(let body), .text(let body, _):
            text = body
        case .code(let lang, _, _):
            language = lang
        case .image(let assetID, _, _):
            // Own images are drawn. A foreign image stays out of the sheet and shows its link and licence.
            if License.isOwn(item.source) {
                imageData = try? document.assets[assetID]?.data()
            } else {
                origin = Self.origin(of: item.source)
            }
        case .link, .frame, .group:
            break
        }
        return SheetPiece(kind: ItemKind(item.content), title: item.title, rect: plan.position(of: placed),
                          fill: fill, swatchName: swatchName, text: text, language: language, imageData: imageData,
                          origin: origin)
    }

    /// The link and the licence of a source, joined by " · ". Nil when the source has neither.
    static func origin(of source: Source?) -> String? {
        let parts = [source?.url?.absoluteString, source?.license].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The colours of the pieces, once each. A colour named by a token shows the token's name; else the swatch name.
    static func colourSwatches(in pieces: [SheetPiece], document: ALFAcolorDocument) -> [SheetSwatch] {
        var seen = Set<String>()
        var out: [SheetSwatch] = []
        for piece in pieces {
            guard let hex = piece.fill, let key = colourKey(hex), !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(SheetSwatch(hex: hex, name: tokenName(for: key, in: document) ?? piece.swatchName))
        }
        return out
    }

    /// The name of the first colour token with this colour, as "set/token".
    private static func tokenName(for key: String, in document: ALFAcolorDocument) -> String? {
        for set in document.tokenSets {
            for token in set.tokens {
                if case .color(let rgb) = token.value, colourKey(rgb.hex) == key {
                    return token.id
                }
            }
        }
        return nil
    }

    /// The hex colour without alpha, in upper case, so that equal colours give equal keys. nil for text that is no colour.
    static func colourKey(_ hex: String) -> String? {
        RGB(hex: hex).map { String($0.hex.prefix(7)).uppercased() }
    }

    /// The name of the space that holds the item, or nil.
    private static func spaceName(holding item: Item, in document: ALFAcolorDocument) -> String? {
        document.board.spaces.first { space in space.items.contains { $0.id == item.id } }?.name
    }

}
