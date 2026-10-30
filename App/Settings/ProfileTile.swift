import Core
import Design
import Hub
import SwiftUI

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
                        .typeStyle(Tokens.TextStyle.title)
                        .foregroundStyle(appearance.color(ink.primary))
                        .frame(width: CGFloat(Tokens.Spacing.step56), height: CGFloat(Tokens.Spacing.step56))
                        .ring(Circle(), appearance.color(ink.line))
                    VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
                        field(profile.name, tone: ink.primary, style: Tokens.TextStyle.title)
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
            .background(shape.fill(selected ? appearance.color(\.ink) : appearance.color(\.well)))
            .ring(shape, selected ? nil : appearance.color(\.lineStrong))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressTile))
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
