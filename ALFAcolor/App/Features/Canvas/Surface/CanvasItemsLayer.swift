import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel

/// The items near the visible part, in board points, under one transform for zoom and pan.
/// Only the items from `CanvasController.drawnItems` get a view.
struct CanvasItemsLayer: View {
    var controller: CanvasController

    var body: some View {
        let view = controller.viewport
        ZStack(alignment: .topLeading) {
            ForEach(controller.drawnItems) { item in
                CanvasItemView(item: item)
                    .frame(width: item.rect.w, height: item.rect.h)
                    .offset(x: item.rect.x, y: item.rect.y)
            }
        }
        .frame(width: controller.size.width, height: controller.size.height, alignment: .topLeading)
        .scaleEffect(view.zoom, anchor: .topLeading)
        .offset(x: -view.offsetX * view.zoom, y: -view.offsetY * view.zoom)
        .allowsHitTesting(false)
    }
}

/// An item as a plain box with its title. The look of each kind of item replaces it.
struct CanvasItemView: View {
    let item: Item

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedRectangle(cornerRadius: theme.radius(.s))
            .fill(theme.color(.surface, scheme))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius(.s))
                    .strokeBorder(theme.color(.border, scheme))
            }
            .overlay(alignment: .topLeading) {
                Text(verbatim: item.title)
                    .font(theme.text(.caption).font)
                    .foregroundStyle(theme.color(.textMuted, scheme))
                    .lineLimit(1)
                    .padding(theme.space(.s2))
            }
    }
}
