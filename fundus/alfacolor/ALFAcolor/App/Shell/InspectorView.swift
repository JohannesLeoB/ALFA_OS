import SwiftUI
import BoardModel

/// Inspector of the main window: the fields of the selection, or of the room. The content is in Features/Inspector.
struct InspectorView: View {
    var canvas: CanvasController
    var interaction: CanvasInteraction
    @Bindable var shell: ShellState

    var body: some View {
        InspectorPanel(store: canvas.store, snap: interaction.snap, interaction: interaction, unit: $shell.lengthUnit)
    }
}
