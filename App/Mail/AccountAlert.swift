import Design
import SwiftUI

struct AccountAlert: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        let line = CGFloat(Tokens.Size.hairline)
        Circle()
            .fill(appearance.color(\.signal))
            .frame(width: CGFloat(Tokens.Spacing.step8), height: CGFloat(Tokens.Spacing.step8))
            .offset(x: line, y: -line)
            .allowsHitTesting(false)
    }
}
