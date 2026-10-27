import Design
import SwiftUI

struct InputField<Trailing: View>: View {
    @Environment(\.appearance) private var appearance
    @Binding var text: String
    let placeholder: Text?
    let labelKey: String
    var secret = false
    var focus: FocusState<Bool>.Binding?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            field
            trailing
        }
        .frame(height: CGFloat(Tokens.Spacing.step28))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(appearance.color(\.ink))
                .frame(height: CGFloat(Tokens.Size.hairline))
        }
    }

    @ViewBuilder
    private var field: some View {
        let base = Group {
            if secret {
                SecureField(text: $text, prompt: placeholder) { appearance.text(labelKey) }
            } else {
                TextField(text: $text, prompt: placeholder) { appearance.text(labelKey) }
            }
        }
        .textFieldStyle(.plain)
        .font(.face(Tokens.TextSize.body))
        .foregroundStyle(appearance.color(\.ink))
        .autocorrectionDisabled()
        .accessibilityLabel(appearance.text(labelKey))
        if let focus {
            base.focused(focus)
        } else {
            base
        }
    }
}

extension InputField where Trailing == EmptyView {
    init(text: Binding<String>, placeholder: Text?, labelKey: String, secret: Bool = false, focus: FocusState<Bool>.Binding? = nil) {
        self.init(text: text, placeholder: placeholder, labelKey: labelKey, secret: secret, focus: focus) { EmptyView() }
    }
}
