import SwiftUI
import ALFAcolorCore
import BoardModel
import Thumbnails

/// The items near the visible part, in board points, under one transform for zoom and pan.
/// Only the items from `CanvasController.drawnItems` get a view. What each kind looks like is in `Features/Canvas/Items`.
/// Items that a drag moves or resizes, copies of a drag, and the item whose text is edited are drawn from the preview
/// of the interaction, above the others. The layer takes no input, except the text field of an edit.
struct CanvasItemsLayer: View {
    var controller: CanvasController
    var interaction: CanvasInteraction

    @State private var thumbnails = ThumbnailCache()

    var body: some View {
        let view = controller.viewport
        let assets = controller.store.document.assets
        let skipped = interaction.hiddenFromBase
        ZStack(alignment: .topLeading) {
            if let space = controller.store.activeSpace {
                ForEach(controller.drawnItems.filter { !skipped.contains($0.id) }) { item in
                    ItemView(presentation: ItemPresentation.make(for: item, in: space, assets: assets),
                             assets: assets, thumbnails: thumbnails, zoom: view.zoom)
                        .offset(x: item.rect.x, y: item.rect.y)
                        .allowsHitTesting(false)
                }
                ForEach(interaction.previewItems) { item in
                    ItemView(presentation: ItemPresentation.make(for: item, in: space, assets: assets),
                             assets: assets, thumbnails: thumbnails, zoom: view.zoom, edit: editing(item))
                        .offset(x: item.rect.x, y: item.rect.y)
                        .allowsHitTesting(interaction.editing?.itemID == item.id)
                }
            }
        }
        .frame(width: controller.size.width, height: controller.size.height, alignment: .topLeading)
        .scaleEffect(view.zoom, anchor: .topLeading)
        .offset(x: -view.offsetX * view.zoom, y: -view.offsetY * view.zoom)
    }

    /// The text field for the item being edited, nil for any other.
    private func editing(_ item: Item) -> TextEditing? {
        guard interaction.editing?.itemID == item.id else { return nil }
        let text = Binding(get: { interaction.editing?.text ?? "" }, set: { interaction.setEditText($0) })
        return TextEditing(text: text, interaction: interaction)
    }
}
