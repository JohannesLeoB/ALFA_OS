import Foundation
import ALFAcolorCore
import Document
import Tokens

/// How an item is drawn: the frame around the content, and the content itself.
public enum ItemChrome: Equatable, Sendable {
    /// A header with the title above the content on a sheet.
    case card
    /// A header band over an open area. The items inside show through.
    case zone
    /// No frame: the content is the item.
    case bare
}

/// What is wrong with an item, if anything. The view shows a placeholder for it.
public enum ItemProblem: Equatable, Sendable {
    /// The document has no file for the image.
    case missingFile
    /// The color is not a hex color.
    case invalidColor
}

/// The text styles of the canvas. A name in a document that is not known reads as `body`.
public enum TextRole: String, Equatable, Sendable, CaseIterable {
    case heading, body, caption

    public init(styleName: String) { self = TextRole(rawValue: styleName) ?? .body }
}

/// The data to draw one item, taken from the item and the document. It holds no view and no theme value:
/// colors are `RGB` values from the item, sizes are in board points.
public struct ItemPresentation: Equatable, Sendable {
    public var id: ItemID
    /// The size of the item in board points.
    public var size: CanvasSize
    /// The text for the header. Empty when the item has no title; the view then names the kind.
    public var title: String
    public var locked: Bool
    public var problem: ItemProblem?
    public var body: Body

    public enum Body: Equatable, Sendable {
        case image(ImageContent)
        case note(NoteContent)
        case link(LinkContent)
        case swatch(SwatchContent)
        case shape(ShapeContent)
        case text(TextContent)
        case group(GroupContent)
        /// A kind that another part draws (code card, frame). Until then it shows a card with its kind.
        case other(kind: OtherKind)
    }

    public enum OtherKind: String, Equatable, Sendable { case code, frame }

    public var chrome: ItemChrome {
        switch body {
        case .image, .note, .link, .swatch, .other: .card
        case .group: .zone
        case .shape, .text: .bare
        }
    }
}

public struct ImageContent: Equatable, Sendable {
    public var assetID: String
    /// The part of the image to show, 0 to 1 on both axes. nil shows all of it.
    public var region: Rect?
    public var fit: ImageFit
}

public struct NoteContent: Equatable, Sendable {
    public var text: String
    public var isEmpty: Bool { text.isEmpty }
}

public struct LinkContent: Equatable, Sendable {
    public var url: URL
    /// The host without a leading "www.". The whole address when the URL has no host.
    public var domain: String
    /// The path and query of the address, or empty.
    public var path: String
    public var note: String?
}

public struct SwatchContent: Equatable, Sendable {
    /// nil when the hex string is not a color.
    public var color: RGB?
    /// "#RRGGBB" in upper case, or the text as it is when it is not a color.
    public var hex: String
    public var name: String?
}

public struct ShapeContent: Equatable, Sendable {
    public var kind: ShapeKind
    public var fill: RGB?
    /// A line without a stroke color is drawn in the text color.
    public var stroke: RGB?
    /// Zero when there is no stroke. A line keeps its width.
    public var strokeWidth: Double
    /// At most half of the shorter side.
    public var cornerRadius: Double
}

public struct TextContent: Equatable, Sendable {
    public var text: String
    public var role: TextRole
}

public struct GroupContent: Equatable, Sendable {
    public var title: String
    /// Items whose center lies inside the group.
    public var childCount: Int
}

extension ItemPresentation {
    /// The data to draw `item`. `space` is the space that holds it, `assets` the images of the document.
    public static func make(for item: Item, in space: Space, assets: AssetStore) -> ItemPresentation {
        var problem: ItemProblem?
        let body: Body
        switch item.content {
        case .image(let assetID, let crop):
            if assets[assetID] == nil { problem = .missingFile }
            body = .image(ImageContent(assetID: assetID, region: ImageLayout.region(crop: crop), fit: crop == nil ? .fit : .fill))
        case .note(let text):
            body = .note(NoteContent(text: text))
        case .link(let url, let note):
            body = .link(LinkDisplay.content(url: url, note: note))
        case .swatch(let hex, let name):
            let color = RGB(hex: hex)
            if color == nil { problem = .invalidColor }
            body = .swatch(SwatchContent(color: color, hex: color.map(Self.opaqueHex) ?? hex, name: name))
        case .shape(let kind, let style):
            body = .shape(ShapeGeometry.content(kind: kind, style: style, size: item.rect))
        case .text(let text, let style):
            body = .text(TextContent(text: text, role: TextRole(styleName: style)))
        case .group(let title):
            let inside = ALFAcolorCore.children(of: item, in: space.items).count
            body = .group(GroupContent(title: title, childCount: inside))
        case .code:
            body = .other(kind: .code)
        case .frame:
            body = .other(kind: .frame)
        }
        return ItemPresentation(id: item.id, size: CanvasSize(width: item.rect.w, height: item.rect.h),
                                title: Self.title(of: item), locked: item.locked, problem: problem, body: body)
    }

    /// The header text: the title of the item. A group shows the title of the group. Without a title, the address of a link.
    static func title(of item: Item) -> String {
        if case .group(let title) = item.content, !title.isEmpty { return title }
        if !item.title.isEmpty { return item.title }
        if case .link(let url, _) = item.content { return LinkDisplay.domain(of: url) }
        return ""
    }

    /// "#RRGGBB" in upper case. The alpha channel is left out.
    private static func opaqueHex(_ color: RGB) -> String {
        var opaque = color
        opaque.a = 1
        return opaque.hex
    }
}
