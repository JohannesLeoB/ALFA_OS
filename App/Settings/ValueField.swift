import Design
import SwiftUI

struct ValueField: View {
    @Environment(\.appearance) private var appearance
    @Binding var text: String
    let labelKey: String
    var prompt: Text?

    var body: some View {
        TextField(text: $text, prompt: prompt?.foregroundStyle(appearance.color(\.inkTertiary))) { appearance.text(labelKey) }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(\.ink))
            .autocorrectionDisabled()
            .padding(.trailing, CGFloat(Tokens.Size.trailingTextInset))
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(Tokens.Spacing.step28))
    }
}
