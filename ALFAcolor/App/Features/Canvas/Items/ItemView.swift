import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel
import Document
import Thumbnails

/// One item on the canvas, drawn from its presentation data. The frame comes from the kind of the item:
/// a card has a header over a sheet, a zone has a band over an open area, a shape or text has none.
struct ItemView: View {
    let presentation: ItemPresentation
    let assets: AssetStore
    let thumbnails: ThumbnailCache
    let zoom: Double
    /// The text of a note or text item that is being edited. nil shows the text as it is.
    var edit: TextEditing?
    /// False while the item lies outside the visible part of the canvas. A code card then rests as an image.
    var onScreen = true

    var body: some View {
        let detail = DetailLevel.level(for: presentation.size, zoom: zoom)
        frame(detail: detail)
            .frame(width: presentation.size.width, height: presentation.size.height, alignment: .topLeading)
            .accessibilityElement(children: isCode ? .contain : .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }

    /// A code card has controls of its own, so VoiceOver reaches them inside the item.
    private var isCode: Bool {
        if case .code = presentation.body { return true }
        return false
    }

    @ViewBuilder
    private func frame(detail: DetailLevel) -> some View {
        switch presentation.chrome {
        case .card:
            if case .code(let content) = presentation.body {
                CodeCardView(presentation: presentation, content: content, detail: detail, zoom: zoom, onScreen: onScreen)
            } else {
                CardFrame(presentation: presentation, detail: detail, zoom: zoom, trailing: trailing) { size in
                    CardBody(presentation: presentation, size: size, detail: detail, zoom: zoom, assets: assets, thumbnails: thumbnails, edit: edit)
                }
            }
        case .zone:
            ZoneFrame(presentation: presentation, detail: detail, zoom: zoom)
        case .bare:
            BareBody(presentation: presentation, detail: detail, edit: edit)
        }
    }

    /// The short text at the end of the header.
    private var trailing: String? {
        if case .swatch(let swatch) = presentation.body, swatch.color != nil { return swatch.hex }
        return nil
    }

    private var label: Text {
        presentation.title.isEmpty ? Text(LocalizedStringKey(presentation.kindKey)) : Text(verbatim: presentation.title)
    }

    private var value: Text {
        switch presentation.body {
        case .note(let note): Text(verbatim: note.text)
        case .text(let text): Text(verbatim: text.text)
        case .link(let link): Text(verbatim: link.url.absoluteString)
        case .swatch(let swatch): Text(verbatim: swatch.hex)
        default: Text(LocalizedStringKey(presentation.kindKey))
        }
    }
}

/// The content of a card, by kind. It gets the size of the body area.
private struct CardBody: View {
    let presentation: ItemPresentation
    let size: CanvasSize
    let detail: DetailLevel
    let zoom: Double
    let assets: AssetStore
    let thumbnails: ThumbnailCache
    let edit: TextEditing?

    var body: some View {
        switch presentation.problem {
        case .missingFile: PlaceholderBody(titleKey: "item.missingFile", symbol: "questionmark.folder", offersSearch: true, detail: detail, zoom: zoom)
        case .invalidColor: PlaceholderBody(titleKey: "item.invalidColor", symbol: "exclamationmark.triangle", offersSearch: false, detail: detail, zoom: zoom)
        case nil: content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch presentation.body {
        case .image(let image):
            ImageBody(content: image, entry: assets[image.assetID], size: size, zoom: zoom, detail: detail, thumbnails: thumbnails)
                .id(image.assetID)
        case .note(let note):
            if let edit {
                TextEditorBody(text: edit.text, role: .body, padded: true, interaction: edit.interaction)
            } else {
                NoteBody(content: note, detail: detail)
            }
        case .link(let link):
            LinkBody(content: link, detail: detail)
        case .swatch(let swatch):
            SwatchBody(content: swatch)
        case .other:
            KindBody(kindKey: presentation.kindKey, detail: detail)
        case .shape, .text, .group, .code:
            EmptyView()
        }
    }
}

/// Shapes and text have no frame.
private struct BareBody: View {
    let presentation: ItemPresentation
    let detail: DetailLevel
    let edit: TextEditing?

    var body: some View {
        switch presentation.body {
        case .shape(let shape): ShapeBody(content: shape, size: presentation.size)
        case .text(let text):
            if let edit {
                TextEditorBody(text: edit.text, role: text.role, padded: false, interaction: edit.interaction)
            } else {
                TextBody(content: text, detail: detail)
            }
        default: EmptyView()
        }
    }
}
