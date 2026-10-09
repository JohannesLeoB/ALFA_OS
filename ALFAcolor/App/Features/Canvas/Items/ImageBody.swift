import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel
import Document
import Thumbnails

/// A downsized copy of the image, cropped and placed in the body. A small copy shows at once,
/// and a larger one replaces it when the item is large on the screen.
struct ImageBody: View {
    let content: ImageContent
    let entry: AssetStore.Entry?
    let size: CanvasSize
    let zoom: Double
    let detail: DetailLevel
    let thumbnails: ThumbnailCache

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale
    @State private var loaded: Thumbnail?
    @State private var unreadable = false

    private struct Request: Equatable {
        var assetID: String
        var edge: Int
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let loaded {
                picture(of: loaded)
            } else if unreadable {
                PlaceholderBody(titleKey: "item.unreadable", symbol: "exclamationmark.triangle", offersSearch: true, detail: detail, zoom: zoom)
            } else if detail == .full {
                Image(systemName: "photo")
                    .font(theme.text(.heading).font)
                    .foregroundStyle(theme.color(.textMuted, scheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .task(id: Request(assetID: content.assetID, edge: wantedEdge)) { await load(edge: wantedEdge) }
    }

    /// The edge of the copy to ask for: a first small look, then what the size on the screen needs.
    /// A copy that is already shown is never replaced by a smaller one.
    private var wantedEdge: Int {
        guard let loaded else { return ThumbnailEdge.steps[2] }
        let original = canvasSize(loaded.original)
        let visible = ImageLayout.visiblePixels(of: original, region: content.region)
        let drawn = ImageLayout.drawRect(visible: visible, in: size, fit: content.fit)
        let needed = ImageLayout.neededEdge(drawn: CanvasSize(width: drawn.w, height: drawn.h), visible: visible,
                                            image: original, scale: displayScale * zoom)
        return max(loaded.edge, ThumbnailEdge.step(for: needed))
    }

    private func load(edge: Int) async {
        guard let entry else { return }
        do {
            let copy = try await thumbnails.thumbnail(assetID: content.assetID, entry: entry, edge: edge)
            if copy.edge >= (loaded?.edge ?? 0) { loaded = copy }
        } catch is CancellationError {
            return
        } catch {
            if loaded == nil { unreadable = true }
        }
    }

    private func picture(of copy: Thumbnail) -> some View {
        let original = canvasSize(copy.original)
        let visible = ImageLayout.visiblePixels(of: original, region: content.region)
        let drawn = ImageLayout.drawRect(visible: visible, in: size, fit: content.fit)
        let cut = ImageLayout.cropRect(region: content.region, copy: canvasSize(copy.size))
        let part = copy.image.cropping(to: CGRect(x: cut.x, y: cut.y, width: cut.w, height: cut.h)) ?? copy.image
        return Image(decorative: part, scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: drawn.w, height: drawn.h)
            .offset(x: drawn.x, y: drawn.y)
    }

    private func canvasSize(_ pixels: PixelSize) -> CanvasSize {
        CanvasSize(width: Double(pixels.width), height: Double(pixels.height))
    }
}

/// The placeholder for an item whose file or value cannot be shown. It says what is wrong and, for a file, what to do.
struct PlaceholderBody: View {
    let titleKey: LocalizedStringKey
    let symbol: String
    let offersSearch: Bool
    let detail: DetailLevel
    let zoom: Double

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let hairline = Hairline.width(zoom: zoom, scale: displayScale)
        VStack(spacing: theme.space(.s1)) {
            if detail == .full {
                Image(systemName: symbol)
                    .font(theme.text(.heading).font)
                Text(titleKey)
                    .font(theme.text(.body).font)
                    .foregroundStyle(theme.color(.text, scheme))
                if offersSearch {
                    Text("item.missingFile.action")
                        .font(theme.text(.caption).font)
                        .foregroundStyle(theme.color(.accent, scheme))
                }
            }
        }
        .foregroundStyle(theme.color(.textMuted, scheme))
        .multilineTextAlignment(.center)
        .padding(theme.space(.s2))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            Rectangle()
                .strokeBorder(theme.color(.border, scheme),
                              style: StrokeStyle(lineWidth: hairline, dash: [theme.space(.s1), theme.space(.s1)]))
                .padding(theme.space(.s2))
        }
    }
}
