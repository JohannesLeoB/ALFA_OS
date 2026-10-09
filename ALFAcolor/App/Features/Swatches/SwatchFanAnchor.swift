import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel
import Tokens

/// The colour fan over a swatch on the canvas. It opens in a popover at the card, already open, and a blade
/// paints the selection. The colours are read once, when the fan opens, so that a painted swatch does not move the blades.
struct SwatchFanAnchor: View {
    var interaction: CanvasInteraction
    let item: Item

    @State private var colors: [RGB]
    @State private var picked: Int?

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    init(interaction: CanvasInteraction, item: Item) {
        self.interaction = interaction
        self.item = item
        let colors = interaction.store.swatchColors
        _colors = State(initialValue: colors)
        _picked = State(initialValue: Self.index(of: item, in: colors))
    }

    var body: some View {
        Color.clear
            .frame(width: CGFloat(item.rect.w), height: CGFloat(item.rect.h))
            .allowsHitTesting(false)
            .popover(isPresented: presented, arrowEdge: .trailing) {
                VStack(spacing: theme.space(.s2)) {
                    SwatchFanView(colors: colors, selection: pickedBlade, startsOpen: true) { index in
                        _ = interaction.paintSelection(hex: colors[index].hex)
                    }
                    .frame(width: side, height: side)
                    if !interaction.canPaintSelection {
                        Text(LocalizedStringKey("fan.noColour"))
                            .themeText(theme.text(.caption))
                            .foregroundStyle(theme.color(.textMuted, scheme))
                    }
                }
                .padding(theme.space(.s3))
            }
    }

    /// The blade that is marked. A blade marks only when the selection can take a colour.
    private var pickedBlade: Binding<Int?> {
        Binding(get: { picked },
                set: { index in
                    guard index == nil || interaction.canPaintSelection else { return }
                    picked = index
                })
    }

    /// The popover is shown while the interaction has this item's fan open. Dismissing it closes the fan.
    private var presented: Binding<Bool> {
        Binding(get: { interaction.fanItem == item.id },
                set: { if !$0 { interaction.closeFan() } })
    }

    /// The fan is four times the large spacing token on each side.
    private var side: CGFloat { theme.space(.s7) * 4 }

    /// The blade that shows the current colour of the swatch, if it is one of the colours of the fan.
    private static func index(of item: Item, in colors: [RGB]) -> Int? {
        guard case .swatch(let hex, _) = item.content, let color = RGB(hex: hex) else { return nil }
        return colors.firstIndex(of: color)
    }
}
