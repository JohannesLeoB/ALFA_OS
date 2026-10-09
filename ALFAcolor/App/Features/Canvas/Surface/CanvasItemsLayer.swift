import SwiftUI
import ALFAcolorCore
import BoardModel
import Performance
import Thumbnails

/// The items near the visible part, in board points, under one transform for zoom and pan.
/// Only the items from `CanvasController.drawnItems` get a view. What each kind looks like is in `Features/Canvas/Items`.
/// Items that a drag moves or resizes, copies of a drag, and the item whose text is edited are drawn from the preview
/// of the interaction, above the others. The layer takes no input, except the text field of an edit and the colour fan.
struct CanvasItemsLayer: View {
    var controller: CanvasController
    var interaction: CanvasInteraction

    @State private var thumbnails = ThumbnailCache()

    var body: some View {
        Signpost.interval("Canvas frame") {
            let view = controller.viewport
            let assets = controller.store.document.assets
            let skipped = interaction.hiddenFromBase
            return ZStack(alignment: .topLeading) {
                if let space = controller.store.activeSpace {
                    ForEach(controller.drawnItems.filter { !skipped.contains($0.id) }) { item in
                        ItemView(presentation: ItemPresentation.make(for: item, in: space, assets: assets),
                                 assets: assets, thumbnails: thumbnails, zoom: view.zoom,
                                 onScreen: Visibility.isOnScreen(item.rect, viewport: view, canvas: controller.size))
                            .offset(x: item.rect.x, y: item.rect.y)
                            .allowsHitTesting(Self.hasControls(item))
                    }
                    ForEach(interaction.previewItems) { item in
                        ItemView(presentation: ItemPresentation.make(for: item, in: space, assets: assets),
                                 assets: assets, thumbnails: thumbnails, zoom: view.zoom, edit: editing(item))
                            .offset(x: item.rect.x, y: item.rect.y)
                            .allowsHitTesting(interaction.editing?.itemID == item.id)
                    }
                    if let fanID = interaction.fanItem, let item = controller.store.item(fanID) {
                        SwatchFanAnchor(interaction: interaction, item: item)
                            .id(fanID)
                            .offset(x: item.rect.x, y: item.rect.y)
                    }
                }
            }
            .frame(width: controller.size.width, height: controller.size.height, alignment: .topLeading)
            .scaleEffect(view.zoom, anchor: .topLeading)
            .offset(x: -view.offsetX * view.zoom, y: -view.offsetY * view.zoom)
            .onChange(of: fanGone) { _, gone in
                if gone { interaction.closeFan() }
            }
        }
    }

    /// The fan is open over an item that is gone, for example after a delete. It closes, so that an undo does not reopen it.
    private var fanGone: Bool {
        guard let id = interaction.fanItem else { return false }
        return controller.store.item(id) == nil
    }

    /// A code card has controls of its own, which take clicks. Other items stay out of the hit test,
    /// so that the canvas takes their clicks and drags.
    private static func hasControls(_ item: Item) -> Bool {
        if case .code = item.content { return true }
        return false
    }

    /// The text field for the item being edited, nil for any other.
    private func editing(_ item: Item) -> TextEditing? {
        guard interaction.editing?.itemID == item.id else { return nil }
        let text = Binding(get: { interaction.editing?.text ?? "" }, set: { interaction.setEditText($0) })
        return TextEditing(text: text, interaction: interaction)
    }
}
