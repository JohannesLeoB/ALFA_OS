import Foundation
import ALFAcolorCore

/// The tools of the palette. One tool is active per window. The active tool decides what a press on the canvas does.
/// The keys and their order follow the shortcut table (ShortcutTable), the drawing tool of the pen is left out.
public enum Tool: String, CaseIterable, Hashable, Sendable {
    case select, directSelect, frame, shape, text, hand, zoom, eyedropper, measure, comment, lab

    /// Key of the name in the string catalog.
    public var nameKey: String { "tool.\(rawValue)" }

    /// Key of the help text in the string catalog. The help text says what the tool does, or why it is dimmed.
    public var helpKey: String { "tool.\(rawValue).help" }

    /// Name of the SF Symbol on the palette button.
    public var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .directSelect: "cursorarrow.rays"
        case .frame: "rectangle.dashed"
        case .shape: "square.on.circle"
        case .text: "textformat"
        case .hand: "hand.raised"
        case .zoom: "magnifyingglass"
        case .eyedropper: "eyedropper"
        case .measure: "ruler"
        case .comment: "text.bubble"
        case .lab: "testtube.2"
        }
    }

    /// The pointer over the canvas while this tool is active.
    public var pointer: ToolPointer {
        switch self {
        case .select, .directSelect, .comment, .lab: .arrow
        case .frame, .shape, .measure: .crosshair
        case .text: .text
        case .hand: .hand
        case .zoom: .zoomIn
        case .eyedropper: .eyedropper
        }
    }

    /// True when the tool does something now. The others stay on the palette, dimmed, with their help text.
    public var isWired: Bool { Self.wired.contains(self) }

    /// The tools that work. `lab` is an action: it opens the lab and the active tool stays as it was.
    public static let wired: Set<Tool> = [.select, .frame, .shape, .text, .hand, .zoom, .measure, .comment, .lab]

    /// The single key of the tool from the shortcut table. nil when the table has none.
    public var key: String? {
        ShortcutTable.commands.first { $0.id == "tool.\(rawValue)" }?.shortcut?.key
    }

    /// The tool that a typed letter selects, from the shortcut table. nil for other letters.
    public static func forKey(_ letter: String) -> Tool? {
        let upper = letter.uppercased()
        return allCases.first { $0.key == upper }
    }
}

/// The pointer shape over the canvas. The view maps each case to a system pointer.
public enum ToolPointer: Equatable, Sendable {
    case arrow, hand, crosshair, zoomIn, text, eyedropper
}
