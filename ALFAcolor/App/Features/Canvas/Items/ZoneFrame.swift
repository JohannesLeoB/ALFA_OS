import SwiftUI
import AppTheme
import BoardModel

/// The frame of a group: a band with the title and the number of items over an open area.
/// The area is not filled, so the items inside and below show through. The corners are square. A zone is flat and casts no shadow.
struct ZoneFrame: View {
    let presentation: ItemPresentation
    let detail: DetailLevel
    let zoom: Double

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let band = CardLayout.band(size: presentation.size, headerHeight: theme.space(.s6))
        let hairline = Hairline.width(zoom: zoom, scale: displayScale)
        ZStack(alignment: .topLeading) {
            Rectangle().strokeBorder(theme.color(.border, scheme), lineWidth: hairline)
            bandView(hairline: hairline)
                .frame(width: band.w, height: band.h)
        }
    }

    private func bandView(hairline: CGFloat) -> some View {
        HStack(spacing: theme.space(.s2)) {
            if detail == .full {
                title
                Spacer(minLength: 0)
                if case .group(let group) = presentation.body {
                    Text("item.group.count \(group.childCount)")
                        .font(theme.text(.caption).font)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(theme.color(.textMuted, scheme))
                }
                if presentation.locked {
                    Image(systemName: "lock.fill")
                        .font(theme.text(.caption).font)
                        .foregroundStyle(theme.color(.textMuted, scheme))
                        .accessibilityLabel("item.locked")
                }
            }
        }
        .padding(.horizontal, theme.space(.s3))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(theme.color(.surface, scheme))
        .overlay {
            Rectangle().strokeBorder(theme.color(.border, scheme), lineWidth: hairline)
        }
    }

    private var title: some View {
        Group {
            if presentation.title.isEmpty {
                Text(LocalizedStringKey(presentation.kindKey))
            } else {
                Text(verbatim: presentation.title)
            }
        }
        .font(theme.text(.heading).font)
        .lineLimit(1)
        .foregroundStyle(theme.color(.text, scheme))
    }
}
