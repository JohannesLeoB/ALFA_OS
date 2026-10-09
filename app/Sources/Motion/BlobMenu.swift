import Foundation

/// The palettes of the blob menu, in display order.
public enum BlobPalette: String, CaseIterable, Equatable, Sendable {
    case transform, align, layers, swatches, tokens
}

/// The form of the blob menu: one blob, or a row with one blob per palette.
public enum BlobLayout: Equatable, Sendable {
    case blob, bar
}

/// An edge of the canvas. A pinned menu sticks to one of them.
public enum BlobEdge: String, CaseIterable, Equatable, Sendable {
    case top, leading, bottom, trailing

    /// True for the edges where a row runs along the edge.
    public var isHorizontal: Bool { self == .top || self == .bottom }
}

/// State of the blob menu. `open` is nil while only the blob or the row shows. When it is set, that
/// palette has spread out of the blob. `last` is the palette that the single blob opens next.
/// `pin` is nil while the menu sits at the top center; otherwise it sticks to that edge.
public struct BlobMenu: Equatable, Sendable {
    public private(set) var layout: BlobLayout = .blob
    public private(set) var open: BlobPalette?
    public private(set) var last: BlobPalette = .transform
    public private(set) var pin: BlobEdge?

    public init() {}

    /// Tap on the single blob: opens the last palette, or closes the open one.
    public mutating func tapBlob() {
        open = open == nil ? last : nil
    }

    /// Tap on a palette: opens it, or closes it when it is already open.
    public mutating func select(_ palette: BlobPalette) {
        if open == palette {
            open = nil
        } else {
            open = palette
            last = palette
        }
    }

    /// Escape, or a tap outside the menu: closes the open palette.
    public mutating func close() {
        open = nil
    }

    /// Switches between the single blob and the row. An open palette stays open.
    public mutating func toggleLayout() {
        layout = layout == .blob ? .bar : .blob
    }

    /// Sticks the menu to an edge and folds the open palette back in.
    public mutating func pin(to edge: BlobEdge) {
        pin = edge
        open = nil
    }

    /// Returns the menu to the top center.
    public mutating func unpin() {
        pin = nil
    }

    /// The edge the menu sits at. Without a pin, that is the top.
    public var edge: BlobEdge { pin ?? .top }
}
