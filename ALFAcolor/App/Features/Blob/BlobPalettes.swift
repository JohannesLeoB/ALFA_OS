import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel
import Motion
import Tokens

extension BlobPalette {
    /// Key of the palette name in the string catalog.
    var titleKey: String {
        switch self {
        case .transform: "blob.palette.transform"
        case .align: "blob.palette.align"
        case .layers: "blob.palette.layers"
        case .swatches: "blob.palette.swatches"
        case .tokens: "blob.palette.tokens"
        }
    }

    /// The symbol on the blob of the palette.
    var symbol: String {
        switch self {
        case .transform: "arrow.up.left.and.arrow.down.right"
        case .align: "align.horizontal.left"
        case .layers: "square.3.layers.3d"
        case .swatches: "paintpalette"
        case .tokens: "swatchpalette"
        }
    }
}

extension BlobEdge {
    /// Key of the edge name in the string catalog.
    var titleKey: String {
        switch self {
        case .top: "blob.edge.top"
        case .leading: "blob.edge.leading"
        case .bottom: "blob.edge.bottom"
        case .trailing: "blob.edge.trailing"
        }
    }
}

/// The content of one palette. The fields come from the inspector sections and the arrangements of the
/// context bar, so the blob menu adds no commands of its own.
struct BlobPaletteContent: View {
    let palette: BlobPalette
    var store: BoardStore
    /// The picks are kept by the menu, so they survive a switch of the palette.
    @Binding var unit: LengthUnit
    @Binding var swatch: Int?
    @Binding var token: Int?

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        switch palette {
        case .transform: selectionForm { PositionSection(store: store, items: store.selectedItems, unit: $unit) }
        case .layers: selectionForm { LayerSection(store: store, items: store.selectedItems) }
        case .align: alignment
        case .swatches: swatches
        case .tokens: tokens
        }
    }

    /// A form for the selection, or a line that asks for a selection first.
    @ViewBuilder
    private func selectionForm<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if store.selectedItems.isEmpty {
            notice("blob.noSelection")
        } else {
            Form { content() }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
        }
    }

    /// The actions that the context bar offers for the selection: arrangements, grouping and locking.
    @ViewBuilder
    private var alignment: some View {
        let count = store.selectedItems.count
        let allLocked = count > 0 && store.selectedItems.allSatisfy(\.locked)
        let actions = ContextBar.actions(count: count)
        if actions.isEmpty {
            notice("blob.noSelection")
        } else {
            VStack(alignment: .leading, spacing: theme.space(.s2)) {
                ForEach(actions, id: \.self) { action in
                    Button {
                        _ = try? store.perform(action, groupTitle: String(localized: "item.kind.group"))
                    } label: {
                        Text(LocalizedStringKey(action.labelKey(allLocked: allLocked)))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(theme.text(.body).font)
            .padding(theme.space(.s3))
        }
    }

    /// The colors of the swatches on the canvas. A blade paints the selection.
    @ViewBuilder
    private var swatches: some View {
        let colors = store.swatchColors
        if store.selectedItems.isEmpty {
            notice("blob.noSelection")
        } else if colors.isEmpty {
            notice("blob.swatches.empty")
        } else {
            fan(colors, selection: $swatch)
        }
    }

    /// The color tokens of the theme, in the mode of the window. A blade paints the selection.
    @ViewBuilder
    private var tokens: some View {
        if store.selectedItems.isEmpty {
            notice("blob.noSelection")
        } else {
            fan(ColorToken.allCases.map { theme.rgb($0, Theme.Mode(scheme)) }, selection: $token)
        }
    }

    /// A fan whose blades paint the selection, one undo step each.
    private func fan(_ colors: [RGB], selection: Binding<Int?>) -> some View {
        SwatchFanView(colors: colors, selection: selection) { index in
            _ = try? store.perform(.setFill(store.selection, hex: colors[index].hex))
        }
        .padding(theme.space(.s3))
    }

    private func notice(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(theme.text(.caption).font)
            .foregroundStyle(theme.color(.textMuted, scheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(theme.space(.s3))
    }
}
