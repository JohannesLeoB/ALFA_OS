import SwiftUI
import AppTheme
import BoardModel
import Motion

/// The open palette: a glass card with the palette header, its content and a footer of three controls.
/// In the single-blob layout the header switches between the palettes; in the row the row does that.
struct BlobCard: View {
    let palette: BlobPalette
    /// Which way the content slides when the palette changes.
    let direction: PanelDirection
    let menu: BlobMenu
    var store: BoardStore
    @Binding var unit: LengthUnit
    @Binding var swatch: Int?
    @Binding var token: Int?
    var onSelect: (BlobPalette) -> Void
    var onLayout: () -> Void
    var onPin: (BlobEdge) -> Void
    var onUnpin: () -> Void
    var onClose: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            header
            BlobPaletteContent(palette: palette, direction: direction, store: store,
                               unit: $unit, swatch: $swatch, token: $token)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            footer
        }
        .padding(theme.space(.s3))
        .onExitCommand(perform: onClose)
    }

    /// The palette switch in the single-blob layout; the title of the palette in the row.
    @ViewBuilder
    private var header: some View {
        if menu.layout == .blob {
            HStack(spacing: theme.space(.s2)) {
                ForEach(BlobPalette.allCases, id: \.self) { item in
                    Button { onSelect(item) } label: {
                        Image(systemName: item.symbol)
                            .foregroundStyle(item == palette ? theme.color(.accent, scheme) : theme.color(.textMuted, scheme))
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey(item.titleKey))
                    .accessibilityLabel(LocalizedStringKey(item.titleKey))
                }
            }
        } else {
            Text(LocalizedStringKey(palette.titleKey))
                .font(theme.text(.heading).font)
        }
    }

    private var footer: some View {
        HStack(spacing: theme.space(.s2)) {
            Button(action: onLayout) {
                Label("blob.layout.toggle", systemImage: menu.layout == .blob ? "rectangle.split.3x1" : "circle")
                    .labelStyle(.iconOnly)
            }
            .help("blob.layout.toggle")
            BlobPinMenu(pin: menu.pin, onPin: onPin, onUnpin: onUnpin)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Label("blob.close", systemImage: "xmark").labelStyle(.iconOnly)
            }
            .help("blob.close")
        }
        .buttonStyle(.plain)
        .font(theme.text(.caption).font)
    }
}

/// Sticks the blob to an edge, or lets it go back to the top. Used by the footer and by the context menu of the blob.
struct BlobPinMenu: View {
    let pin: BlobEdge?
    var onPin: (BlobEdge) -> Void
    var onUnpin: () -> Void

    var body: some View {
        Menu {
            ForEach(BlobEdge.allCases, id: \.self) { edge in
                Button(LocalizedStringKey(edge.titleKey)) { onPin(edge) }
            }
            if pin != nil {
                Divider()
                Button("blob.unpin", action: onUnpin)
            }
        } label: {
            Label("blob.pin", systemImage: pin == nil ? "pin" : "pin.fill").labelStyle(.iconOnly)
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("blob.pin")
    }
}

/// The width of the hairline edge of the blob menu.
private let blobHairline: CGFloat = 1

/// Liquid Glass for the blob menu, or a calm surface with a hairline edge when transparency is reduced.
struct BlobGlass<S: InsettableShape>: ViewModifier {
    let shape: S

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(theme.color(.surface, scheme), in: shape)
                .overlay(shape.strokeBorder(theme.color(.border, scheme), lineWidth: blobHairline))
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}
