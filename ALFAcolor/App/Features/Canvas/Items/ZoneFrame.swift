import SwiftUI
import AppTheme
import BoardModel

/// The frame of a group: the zone is filled with its full colour, and a band with the title lies on top.
/// The corners are square. A zone is flat and casts no shadow.
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
            Rectangle().fill(theme.color(tint, scheme))
            Rectangle().strokeBorder(theme.color(.border, scheme), lineWidth: hairline)
            bandView(hairline: hairline)
                .frame(width: band.w, height: band.h)
        }
    }

    /// The zone colour of the group. A group without a colour name has the paper colour.
    private var tint: ColorToken {
        guard case .group(let group) = presentation.body else { return .zonePaper }
        return ZoneTint.token(named: group.tint)
    }

    private func bandView(hairline: CGFloat) -> some View {
        HStack(spacing: theme.space(.s2)) {
            if detail == .full {
                title
                Spacer(minLength: 0)
                if case .group(let group) = presentation.body {
                    Text("item.group.count \(group.childCount)")
                        .themeText(theme.text(.caption))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(theme.color(.textMuted, scheme))
                }
                if presentation.locked {
                    Image(systemName: "lock.fill")
                        .themeText(theme.text(.caption))
                        .foregroundStyle(theme.color(.textMuted, scheme))
                        .accessibilityLabel("item.locked")
                }
            }
        }
        .padding(.horizontal, theme.space(.s3))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        .themeText(theme.text(.zone))
        .lineLimit(1)
        .foregroundStyle(Color(ZoneTint.ink(on: tint)))
    }
}
