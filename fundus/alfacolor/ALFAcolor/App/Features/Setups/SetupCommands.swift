import SwiftUI
import AppKit
import ALFAcolorCore
import BoardModel

/// The setups in the Window menu. A click applies one; "save" keeps the current arrangement as a new setup.
struct SetupCommands: Commands {
    @FocusedValue(\.shell) private var shell
    @FocusedValue(\.canvas) private var canvas
    @FocusedValue(\.interaction) private var interaction

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Menu("menu.window.setup") {
                ForEach(Setup.presets + SetupLibrary.shared.saved) { setup in
                    Button {
                        apply(setup)
                    } label: {
                        SetupLabel(setup: setup)
                    }
                    .disabled(shell == nil || interaction == nil)
                }
                Divider()
                Button("menu.window.setup.save") {
                    saveCurrent()
                }
                .disabled(shell == nil || interaction == nil)
            }
        }
    }

    /// Shows the panels, rulers, grid, unit and tool of the setup in the front window.
    @MainActor
    private func apply(_ setup: Setup) {
        guard let shell, let interaction else { return }
        shell.sidebarVisible = setup.sidebar
        shell.inspectorVisible = setup.inspector
        shell.rulersVisible = setup.rulers
        shell.lengthUnit = LengthUnit(setup.unit)
        interaction.setGridShown(setup.grid)
        // The lab is an action, not a setting: a setup never opens it.
        if setup.tool != .lab {
            shell.pick(setup.tool, in: interaction, canvas: canvas)
        }
    }

    /// Asks for a name and saves the current arrangement of the front window.
    @MainActor
    private func saveCurrent() {
        guard let shell, let interaction, let name = askName() else { return }
        let tool = interaction.tools.active == .lab ? Tool.select : interaction.tools.active
        SetupLibrary.shared.add(Setup(id: UUID().uuidString, name: name, sidebar: shell.sidebarVisible,
                                      inspector: shell.inspectorVisible, rulers: shell.rulersVisible,
                                      grid: interaction.gridShown, unit: UnitChoice(shell.lengthUnit), tool: tool))
    }

    /// A small alert with a text field. nil when the user cancels or the name is empty.
    @MainActor
    private func askName() -> String? {
        let alert = NSAlert()
        alert.messageText = String(localized: "menu.window.setup.save")
        alert.informativeText = String(localized: "setup.askName")
        alert.addButton(withTitle: String(localized: "setup.save.ok"))
        alert.addButton(withTitle: String(localized: "setup.cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = String(localized: "setup.defaultName")
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

/// The name of a setup in the menu: a catalog key for the presets, the typed name otherwise.
private struct SetupLabel: View {
    let setup: Setup

    var body: some View {
        if setup.isPreset {
            Text(LocalizedStringKey(setup.name))
        } else {
            Text(verbatim: setup.name)
        }
    }
}
