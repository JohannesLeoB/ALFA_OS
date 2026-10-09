import SwiftUI
import UniformTypeIdentifiers
import ALFAcolorCore
import BoardModel

/// What a drag from the library carries: the place of one item. The canvas copies the item on drop.
struct LibraryDrag: Codable, Transferable {
    var ref: ItemRef

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// Takes library drags on the canvas. A drop lands where it is released, as the import drop does.
/// It takes only `LibraryDrag`, so it never mixes with files or text that the import takes.
struct LibraryDropTarget: ViewModifier {
    let controller: CanvasController
    let interaction: CanvasInteraction

    func body(content: Self.Content) -> some View {
        content.dropDestination(for: LibraryDrag.self) { drags, location in
            let point = controller.viewport.boardPoint(canvasX: location.x, canvasY: location.y)
            return interaction.insertLibraryItems(drags.map(\.ref), atX: point.x, y: point.y)
        }
    }
}
