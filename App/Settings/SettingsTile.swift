import AppKit
import Design
import SwiftUI

struct SettingsTile: View {
    @Environment(\.appearance) private var appearance
    let name: LocalizedStringKey
    let initial: String
    let logo: NSImage?
    let sub: String
    let bad: Bool
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        let lift = hovering && !selected ? CGFloat(Tokens.Size.tileHoverLift) : 0
        let height = CGFloat(Tokens.Size.settingsTileHeight)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                badge
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4) / 2) {
                    Text(name, bundle: appearance.bundle)
                        .lineLimit(1)
                        .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                        .foregroundStyle(appearance.color(selected ? \.lane : \.ink))
                    appearance.text(sub)
                        .lineLimit(1)
                        .font(.face(Tokens.TextSize.small))
                        .foregroundStyle(appearance.color(selected ? \.lane : (bad ? \.signal : \.inkTertiary)))
                }
            }
            .padding(CGFloat(Tokens.Spacing.step12))
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            .background(shape.fill(selected ? appearance.color(\.ink) : appearance.color(\.well)))
            .ring(shape, hovering && !selected ? appearance.color(\.inkTertiary) : nil)
            .offset(y: -lift)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var badge: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        return ZStack {
            if let image = logo {
                Circle().fill(appearance.color(\.lane))
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(Tokens.Size.tileLogoSize), height: CGFloat(Tokens.Size.tileLogoSize))
            } else {
                Text(verbatim: initial)
                    .font(.face(Tokens.TextSize.small, weight: Tokens.Weight.medium))
                    .foregroundStyle(appearance.color(selected ? \.lane : \.ink))
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .ring(Circle(), appearance.color(selected ? \.lane : \.lineStrong))
    }
}
