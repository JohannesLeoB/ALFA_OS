import Foundation

/// The keys held during a pointer action.
public struct PointerModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shift = PointerModifiers(rawValue: 1 << 0)
    public static let command = PointerModifiers(rawValue: 1 << 1)
    public static let option = PointerModifiers(rawValue: 1 << 2)

    /// A click with Shift or Command adds to the selection instead of replacing it.
    public var extendsSelection: Bool { contains(.shift) || contains(.command) }
}

/// The measures of the selection aids, in screen points. The design system names them; the contract has
/// no tokens for them yet, so they are fixed here. Colors come from the theme.
public enum SelectionStyle {
    /// Width of the outline around a selected item. The color is the text color.
    public static let outlineWidth = 2.0
    /// The space between an item and its outline.
    public static let outlineGap = 3.0
    /// Width of the lasso border and of the snap lines. The color is the coral color.
    public static let lineWidth = 1.0
    /// Opacity of the lasso fill, in the coral color.
    public static let lassoFillOpacity = 0.08
    /// Width of the ring around an item whose text is edited. The color is the coral color.
    public static let focusRingWidth = 2.0
}
