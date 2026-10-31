import Design
import SwiftUI

struct ValueField: View {
    @Environment(\.appearance) private var appearance
    @Binding var text: String
    let labelKey: String
    var prompt: Text?
    var onEnd: (() -> Void)?
    @FocusState private var focused: Bool

    var body: some View {
        TextField(text: $text, prompt: prompt?.foregroundStyle(appearance.color(\.inkTertiary))) { appearance.text(labelKey) }
            .textFieldStyle(.plain)
            .focused($focused)
            .onSubmit { onEnd?() }
            .onChange(of: focused) { _, now in if !now { onEnd?() } }
            .multilineTextAlignment(.trailing)
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(\.ink))
            .autocorrectionDisabled()
            .padding(.trailing, CGFloat(Tokens.Size.trailingTextInset))
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(Tokens.Spacing.step28))
    }
}
