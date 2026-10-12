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
/// `previous` is the palette that was open before the last change. It gives the direction of a switch.
/// `swatch` and `token` are the picks of the palettes. They stay when the palette changes or closes.
public struct BlobMenu: Equatable, Sendable {
    public private(set) var layout: BlobLayout = .blob
    public private(set) var open: BlobPalette?
    public private(set) var last: BlobPalette = .transform
    public private(set) var pin: BlobEdge?
    public private(set) var previous: BlobPalette?
    public private(set) var swatch: Int?
    public private(set) var token: Int?

    public init() {}

    /// Tap on the single blob: opens the last palette, or closes the open one.
    public mutating func tapBlob() {
        remember()
        open = open == nil ? last : nil
    }

    /// Tap on a palette: opens it, or closes it when it is already open.
    public mutating func select(_ palette: BlobPalette) {
        remember()
        if open == palette {
            open = nil
        } else {
            open = palette
            last = palette
        }
    }

    /// Escape, or a tap outside the menu: closes the open palette.
    public mutating func close() {
        remember()
        open = nil
    }

    /// Switches between the single blob and the row. An open palette stays open.
    public mutating func toggleLayout() {
        remember()
        layout = layout == .blob ? .bar : .blob
    }

    /// Sticks the menu to an edge and folds the open palette back in.
    public mutating func pin(to edge: BlobEdge) {
        remember()
        pin = edge
        open = nil
    }

    /// Returns the menu to the top center.
    public mutating func unpin() {
        remember()
        pin = nil
    }

    /// Picks a swatch of the fan. nil clears the pick.
    public mutating func pickSwatch(_ index: Int?) {
        swatch = index
    }

    /// Picks a color token of the fan. nil clears the pick.
    public mutating func pickToken(_ index: Int?) {
        token = index
    }

    /// The edge the menu sits at. Without a pin, that is the top.
    public var edge: BlobEdge { pin ?? .top }

    /// Keeps the palette that is open before a change, so that the direction of the change is known.
    private mutating func remember() {
        previous = open
    }
}
