import ShellCore
import SwiftUI

struct InputField<Trailing: View>: View {
    @Environment(\.design) private var design
    @Binding var text: String
    let placeholder: Text?
    let labelKey: String
    var secret = false
    var focus: FocusState<Bool>.Binding?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            field
            trailing
        }
        .frame(height: CGFloat(Design.Spacing.step28))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(design.color(\.ink))
                .frame(height: CGFloat(Design.Size.hairline))
        }
    }

    @ViewBuilder
    private var field: some View {
        let base = Group {
            if secret {
                SecureField(text: $text, prompt: placeholder) { word(labelKey) }
            } else {
                TextField(text: $text, prompt: placeholder) { word(labelKey) }
            }
        }
        .textFieldStyle(.plain)
        .font(.face(Design.TextSize.body))
        .foregroundStyle(design.color(\.ink))
        .autocorrectionDisabled()
        .accessibilityLabel(word(labelKey))
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
