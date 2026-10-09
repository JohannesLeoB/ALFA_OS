import Foundation
import ALFAcolorCore

/// A work setup: which panels show, the rulers, the grid, the unit and the active tool.
/// It never holds the document. The shell applies it; the app keeps the saved setups in a file.
public struct Setup: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    /// A name the user gave, or for a preset the key of its name in the string catalog.
    public var name: String
    public var sidebar: Bool
    public var inspector: Bool
    public var rulers: Bool
    public var grid: Bool
    public var unit: UnitChoice
    /// The raw name of the tool, so the file stays readable. Unknown names give the select tool.
    public var toolName: String

    public init(id: String, name: String, sidebar: Bool, inspector: Bool, rulers: Bool, grid: Bool, unit: UnitChoice, tool: Tool) {
        self.id = id
        self.name = name
        self.sidebar = sidebar
        self.inspector = inspector
        self.rulers = rulers
        self.grid = grid
        self.unit = unit
        self.toolName = tool.rawValue
    }

    /// The active tool.
    public var tool: Tool {
        get { Tool(rawValue: toolName) ?? .select }
        set { toolName = newValue.rawValue }
    }

    /// True for the four presets, whose names are keys of the string catalog.
    public var isPreset: Bool { Setup.presets.contains { $0.id == id } }

    /// The four presets of the app, in the order of the menu.
    public static let presets: [Setup] = [collecting, placing, system, presenting]

    /// Sorting: wide sidebar, narrow inspector, no rulers.
    public static let collecting = Setup(id: "collect", name: "setup.collect", sidebar: true, inspector: true,
                                         rulers: false, grid: false, unit: .point, tool: .select)
    /// Mockups: layers, inspector, rulers and grid on.
    public static let placing = Setup(id: "place", name: "setup.place", sidebar: true, inspector: true,
                                      rulers: true, grid: true, unit: .point, tool: .select)
    /// Token work: the token sets, swatches and building blocks.
    public static let system = Setup(id: "system", name: "setup.system", sidebar: true, inspector: true,
                                     rulers: false, grid: false, unit: .point, tool: .select)
    /// Showing a prototype: everything off.
    public static let presenting = Setup(id: "present", name: "setup.present", sidebar: false, inspector: false,
                                         rulers: false, grid: false, unit: .point, tool: .select)
}
