import AppKit
import Design
import Hub
import SwiftUI

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
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSide(logo), height: logoSide(logo))
                } else {
                    shape.fill(appearance.color(\.well))
                    Text(verbatim: String(name.prefix(1)))
                        .typeStyle(Tokens.TextStyle.title)
                        .foregroundStyle(appearance.color(\.ink))
                }
            }
            .frame(width: side, height: side)
            .clipShape(shape)
            .ring(shape, info.logo.flatMap { $0.isWide ? nil : appearance.color(\.line) })
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
                Text(verbatim: name)
                    .typeStyle(Tokens.TextStyle.title)
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

    private func logoSide(_ logo: IntegrationLogo) -> CGFloat {
        CGFloat(logo.isWide ? SheetValues.heroLogoWide : Tokens.Spacing.step56)
    }
}
