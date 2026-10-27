import Design
import SwiftUI

struct SmallText: View {
    let text: Text
    var tone: KeyPath<Colors, ColorValue> = \.inkTertiary

    var body: some View {
        text
            .designText(tone, size: Tokens.TextSize.small)
            .lineLimit(1)
    }
}
