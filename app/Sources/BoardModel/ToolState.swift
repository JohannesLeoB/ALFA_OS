import ALFAcolorCore
import Geometry

/// The options of the tools that take one. They belong to the window, not to the document.
public struct ToolOptions: Equatable, Sendable {
    /// The device of a frame that is drawn with the frame tool. The first preset of the device list.
    public var frameDeviceID: String = Device.presets.first?.id ?? "mbp14"
    /// The kind of a shape that is drawn with the shape tool.
    public var shapeKind: ShapeKind = .rectangle
    /// The text style of a text that is set with the text tool: "heading", "body" or "caption".
    public var textStyle: String = "body"

    public init() {}
}

/// The state of the palette in one window: the active tool and the options. A choice changes only the active tool.
public struct ToolState: Equatable, Sendable {
    /// The tool that a press on the canvas works with.
    public private(set) var active: Tool = .select
    public var options = ToolOptions()

    public init() {}

    /// Makes the tool the active one. Returns false for a tool that does not work yet, and leaves the state as it was.
    /// The lab is an action: choosing it returns true, and the active tool stays as it was.
    @discardableResult
    public mutating func choose(_ tool: Tool) -> Bool {
        guard tool.isWired else { return false }
        if tool != .lab { active = tool }
        return true
    }

    /// Returns to the selection tool. Returns false when it is active already.
    @discardableResult
    public mutating func leave() -> Bool {
        guard active != .select else { return false }
        active = .select
        return true
    }
}
