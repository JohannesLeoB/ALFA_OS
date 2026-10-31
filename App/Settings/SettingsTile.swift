import Design
import Hub
import SwiftUI

struct SettingsTile: View {
    @Environment(\.appearance) private var appearance
    let name: LocalizedStringKey
    let initial: String
    let logo: IntegrationLogo?
    let sub: String?
    let bad: Bool
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        let lift = hovering ? CGFloat(Tokens.Size.tileHoverLift) : 0
        let height = CGFloat(Tokens.Size.settingsTileHeight)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                badge
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
                    Text(name, bundle: appearance.bundle)
                        .lineLimit(1)
                        .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                        .foregroundStyle(appearance.color(selected ? \.lane : \.ink))
                    (sub.map { appearance.text($0) } ?? Text(verbatim: ""))
                        .lineLimit(1)
                        .font(.face(Tokens.TextSize.small))
                        .foregroundStyle(appearance.color(selected ? \.lane : (bad ? \.signal : \.inkTertiary)))
                }
            }
            .padding(CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            .background(shape.fill(selected ? appearance.color(\.ink) : appearance.color(\.well)))
            .background {
                if hovering, let layer = Shadows.overviewHoverLight.first {
                    shape.inset(by: CGFloat(-layer.spread))
                        .fill(appearance.paint(layer.color))
                        .blur(radius: CGFloat(layer.blur / 2))
                        .offset(x: CGFloat(layer.x), y: CGFloat(layer.y))
                }
            }
            .offset(y: -lift)
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressTile))
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var badge: some View {
        let side = CGFloat(Tokens.Spacing.step44)
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        let image = logo?.image
        return ZStack {
            if let logo, let image {
                let logoSide = logo.side(field: Tokens.Spacing.step44, mark: Tokens.Spacing.step24)
                shape.fill(appearance.color(logo.ground))
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSide, height: logoSide)
            } else {
                Text(verbatim: initial)
                    .typeStyle(Tokens.TextStyle.mark)
                    .foregroundStyle(appearance.color(selected ? \.lane : \.ink))
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .ring(shape, image == nil ? appearance.color(selected ? \.lane : \.lineStrong) : nil)
    }
}
