import ShellCore
import SwiftUI

struct InputField<Trailing: View>: View {
    @Environment(\.design) private var design
    @Binding var text: String
    let placeholder: Text
    let labelKey: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            TextField(text: $text, prompt: placeholder) { word(labelKey) }
                .textFieldStyle(.plain)
                .font(.system(size: CGFloat(Design.TextSize.body)))
                .foregroundStyle(design.color(\.ink))
                .autocorrectionDisabled()
                .accessibilityLabel(word(labelKey))
            trailing
        }
        .frame(height: CGFloat(Design.Spacing.step28))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(design.color(\.ink))
                .frame(height: CGFloat(Design.Size.hairline))
        }
    }
}

extension InputField where Trailing == EmptyView {
    init(text: Binding<String>, placeholder: Text, labelKey: String) {
        self.init(text: text, placeholder: placeholder, labelKey: labelKey) { EmptyView() }
    }
}
