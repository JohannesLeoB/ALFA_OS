import SwiftUI
import AppTheme
import BoardModel

/// The frame of a card: a header with the title over a body on a sheet. The corners are square.
/// The sheet casts the shadow of the system. The border is one device pixel wide at every zoom.
struct CardFrame<Content: View>: View {
    let presentation: ItemPresentation
    let detail: DetailLevel
    let zoom: Double
    var trailing: String?
    @ViewBuilder var content: (CanvasSize) -> Content

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let regions = CardLayout.regions(size: presentation.size, headerHeight: theme.space(.s6))
        let hairline = Hairline.width(zoom: zoom, scale: displayScale)
        ZStack(alignment: .topLeading) {
            Rectangle().fill(theme.color(.surface, scheme))
            content(CanvasSize(width: regions.body.w, height: regions.body.h))
                .frame(width: regions.body.w, height: regions.body.h, alignment: .topLeading)
                .clipped()
                .offset(x: regions.body.x, y: regions.body.y)
            if let header = regions.header {
                ItemHeader(presentation: presentation, trailing: trailing, showsText: detail == .full, hairline: hairline)
                    .frame(width: header.w, height: header.h)
                    .offset(x: header.x, y: header.y)
            }
            Rectangle().strokeBorder(theme.color(.border, scheme), lineWidth: hairline)
        }
        .modifier(Lift(detail: detail))
    }
}

/// The shadow under cards and zones. It is the shadow of the system, with the blur and the offset taken from the spacing
/// of the theme. Small items cast none.
struct Lift: ViewModifier {
    let detail: DetailLevel
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let full = detail == .full
        content.shadow(radius: full ? theme.space(.s4) : 0, y: full ? theme.space(.s2) : 0)
    }
}

/// The header of a card: the title, a short text and the lock.
struct ItemHeader: View {
    let presentation: ItemPresentation
    var trailing: String?
    let showsText: Bool
    let hairline: CGFloat

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: theme.space(.s2)) {
            if showsText {
                title
                Spacer(minLength: 0)
                if let trailing {
                    Text(verbatim: trailing)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(theme.color(.textMuted, scheme))
                }
                if presentation.locked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(theme.color(.textMuted, scheme))
                        .accessibilityLabel("item.locked")
                }
            }
        }
        .font(theme.text(.caption).font)
        .padding(.horizontal, theme.space(.s3))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(theme.color(.surface, scheme))
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.color(.border, scheme)).frame(height: hairline)
        }
    }

    @ViewBuilder
    private var title: some View {
        Group {
            if presentation.title.isEmpty {
                Text(LocalizedStringKey(presentation.kindKey))
            } else {
                Text(verbatim: presentation.title)
            }
        }
        .lineLimit(1)
        .foregroundStyle(theme.color(.text, scheme))
    }
}
