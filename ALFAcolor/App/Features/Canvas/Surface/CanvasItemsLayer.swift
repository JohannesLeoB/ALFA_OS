import SwiftUI
import ALFAcolorCore
import BoardModel
import Thumbnails

/// The items near the visible part, in board points, under one transform for zoom and pan.
/// Only the items from `CanvasController.drawnItems` get a view. What each kind looks like is in `Features/Canvas/Items`.
struct CanvasItemsLayer: View {
    var controller: CanvasController

    @State private var thumbnails = ThumbnailCache()

    var body: some View {
        let view = controller.viewport
        let assets = controller.store.document.assets
        ZStack(alignment: .topLeading) {
            if let space = controller.store.activeSpace {
                ForEach(controller.drawnItems) { item in
                    ItemView(presentation: ItemPresentation.make(for: item, in: space, assets: assets),
                             assets: assets, thumbnails: thumbnails, zoom: view.zoom)
                        .offset(x: item.rect.x, y: item.rect.y)
                }
            }
        }
        .frame(width: controller.size.width, height: controller.size.height, alignment: .topLeading)
        .scaleEffect(view.zoom, anchor: .topLeading)
        .offset(x: -view.offsetX * view.zoom, y: -view.offsetY * view.zoom)
        .allowsHitTesting(false)
    }
}
