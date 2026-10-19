import AppKit
import ShellCore
import SwiftUI

struct SettingsTile: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let name: LocalizedStringKey
    let initial: String
    let logo: NSImage?
    let sub: String
    let bad: Bool
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        let lift = hovering && !selected ? CGFloat(Design.Size.tileHoverLift) : 0
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                badge
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4) / 2) {
                    Text(name)
                        .lineLimit(1)
                        .font(.face(Design.TextSize.body, weight: Design.Weight.medium))
                        .foregroundStyle(design.color(selected ? \.lane : \.ink))
                    Text(LocalizedStringKey(sub))
                        .lineLimit(1)
                        .font(.face(Design.TextSize.small))
                        .foregroundStyle(design.color(selected ? \.lane : (bad ? \.signal : \.inkTertiary)))
                }
            }
            .padding(CGFloat(Design.Spacing.step12))
            .frame(maxWidth: .infinity, minHeight: CGFloat(SheetValues.settingsTileHeight), maxHeight: CGFloat(SheetValues.settingsTileHeight), alignment: .topLeading)
            .background(shape.fill(selected ? design.color(\.ink) : design.color(\.well)))
            .ring(shape, hovering && !selected ? design.color(\.inkTertiary) : nil)
            .offset(y: -lift)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var badge: some View {
        let side = CGFloat(Design.Size.symbolSize)
        return ZStack {
            if let image = logo {
                Circle().fill(Color(.sRGB, red: DesignColors.light.lane.red, green: DesignColors.light.lane.green, blue: DesignColors.light.lane.blue, opacity: DesignColors.light.lane.alpha))
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(Design.Size.tileLogoSize), height: CGFloat(Design.Size.tileLogoSize))
            } else {
                Text(verbatim: initial)
                    .font(.face(Design.TextSize.small, weight: Design.Weight.medium))
                    .foregroundStyle(design.color(selected ? \.lane : \.ink))
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .ring(Circle(), design.color(selected ? \.lane : \.lineStrong))
    }
}
