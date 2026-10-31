import AppKit
import Core
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
        .help(Text(name, bundle: appearance.bundle))
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

struct ProfileTile: View {
    @Environment(\.appearance) private var appearance
    let profile: UserProfile
    let addresses: [String]
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        let ink = InkSet.of(selected)
        Button(action: action) {
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step16)) {
                HStack(spacing: CGFloat(Tokens.Spacing.step16)) {
                    Text(verbatim: profile.code.isEmpty ? Initials.from(profile.name) : profile.code)
                        .font(.face(Tokens.TextSize.title, weight: Tokens.Weight.medium))
                        .tracking(CGFloat(Tokens.Tracking.mark * Tokens.TextSize.title))
                        .foregroundStyle(appearance.color(ink.primary))
                        .frame(width: CGFloat(Tokens.Spacing.step56), height: CGFloat(Tokens.Spacing.step56))
                        .ring(Circle(), appearance.color(ink.line))
                    VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
                        Group {
                            if profile.name.isEmpty {
                                appearance.text(SettingsKeys.valueEmpty).foregroundStyle(appearance.color(ink.tertiary))
                            } else {
                                Text(verbatim: profile.name).foregroundStyle(appearance.color(ink.primary))
                            }
                        }
                        .font(.face(Tokens.TextSize.title, weight: Tokens.Weight.medium))
                        .lineHeight(Tokens.LineHeight.heading, size: Tokens.TextSize.title)
                        field(profile.role, tone: ink.tertiary, style: Tokens.TextStyle.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                fact("settings.identity.code", profile.code.isEmpty ? Initials.from(profile.name) : profile.code, ink)
                fact("settings.identity.phone", profile.phone, ink)
                VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
                    appearance.text("settings.profile.addresses")
                        .typeStyle(Tokens.TextStyle.caption)
                        .foregroundStyle(appearance.color(ink.tertiary))
                    if addresses.isEmpty {
                        field("", tone: ink.tertiary, style: Tokens.TextStyle.body)
                    }
                    ForEach(addresses, id: \.self) { address in
                        Text(verbatim: address)
                            .typeStyle(Tokens.TextStyle.body)
                            .foregroundStyle(appearance.color(ink.primary))
                    }
                }
            }
            .padding(CGFloat(Tokens.Spacing.step16))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(selected ? appearance.color(\.inverse) : appearance.color(\.well)))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressRow))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func fact(_ key: String, _ value: String, _ ink: InkSet) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
            appearance.text(key)
                .typeStyle(Tokens.TextStyle.caption)
                .foregroundStyle(appearance.color(ink.tertiary))
            field(value, tone: ink.primary, style: Tokens.TextStyle.body)
        }
    }

    @ViewBuilder
    private func field(_ value: String, tone: KeyPath<Colors, ColorValue>, style: TypeStyle) -> some View {
        if value.isEmpty {
            appearance.text(SettingsKeys.valueEmpty)
                .typeStyle(style)
                .foregroundStyle(appearance.color(InkSet.of(selected).tertiary))
        } else {
            Text(verbatim: value)
                .typeStyle(style)
                .foregroundStyle(appearance.color(tone))
        }
    }
}

struct IntegrationHero: View {
    @Environment(\.appearance) private var appearance
    let info: IntegrationInfo

    var body: some View {
        let side = CGFloat(Tokens.Spacing.step56)
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.contextMenu))
        let name = appearance.string(info.nameKey)
        HStack(spacing: CGFloat(Tokens.Spacing.step16)) {
            ZStack {
                if let logo = info.logo, let image = logo.image {
                    shape.fill(appearance.color(logo.ground))
                    let logoSide = logo.side(field: Tokens.Spacing.step56, mark: Tokens.Spacing.step32)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSide, height: logoSide)
                } else {
                    shape.fill(appearance.color(\.well))
                    Text(verbatim: String(name.prefix(1)))
                        .typeStyle(Tokens.TextStyle.title)
                        .foregroundStyle(appearance.color(\.ink))
                }
            }
            .frame(width: side, height: side)
            .clipShape(shape)
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
                Text(verbatim: name)
                    .font(.face(Tokens.TextSize.title, weight: Tokens.Weight.medium))
                    .lineHeight(Tokens.LineHeight.heading, size: Tokens.TextSize.title)
                    .foregroundStyle(appearance.color(\.ink))
                    .lineLimit(1)
                appearance.text(info.useKey)
                    .typeStyle(Tokens.TextStyle.caption)
                    .foregroundStyle(appearance.color(\.inkTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, CGFloat(Tokens.Spacing.step4))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
        .padding(.bottom, CGFloat(Tokens.Spacing.step12))
    }
}

extension IntegrationLogo {
    var image: NSImage? { NSImage(named: resource) }

    var ground: KeyPath<Colors, ColorValue> {
        switch resource {
        case "claude": \.claudeClay
        case "sevdesk": \.sevdeskRed
        case "clockodo": \.clockodoBlue
        case "dhl": \.dhlYellow
        default: \.sheet
        }
    }

    func side(field: Double, mark: Double) -> CGFloat {
        switch kind {
        case .full: CGFloat(field)
        case .wide: CGFloat(field - Tokens.Spacing.step8)
        case .mark: CGFloat(mark)
        }
    }
}

extension LinkState {
    var connection: ConnectionState {
        switch self {
        case .connected: .connected
        case .connecting: .connecting
        case .working: .working
        case .notConnected: .notConnected
        case .failed: .failed
        case .unreadable: .unreadable
        }
    }
}
