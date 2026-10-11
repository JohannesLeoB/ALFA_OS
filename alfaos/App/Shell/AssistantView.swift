import ShellCore
import SwiftUI

struct AssistantView: View {
    let theme: Theme
    let model: ShellModel

    var body: some View {
        let radius = theme.length(.componentLaneRadius)
        VStack(alignment: .leading, spacing: theme.length(.spaceM)) {
            HStack {
                theme.text("assistant.title")
                    .font(theme.font(.name))
                    .foregroundStyle(theme.color(.colorTextPrimary))
                Spacer(minLength: 0)
                Button { model.closeAssistant() } label: {
                    Image(systemName: "xmark")
                        .font(theme.font(.textButton))
                        .foregroundStyle(theme.color(.colorTextTertiary))
                        .frame(width: theme.length(.sizeControlS), height: theme.length(.sizeControlS))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.text("assistant.close"))
            }
            theme.text("assistant.empty")
                .font(theme.font(.callout))
                .foregroundStyle(theme.color(.colorTextSecondary))
                .frame(maxWidth: .infinity, minHeight: theme.length(.layoutReadingMaxWidth) / 3, alignment: .topLeading)
            theme.text("assistant.field")
                .font(theme.font(.callout))
                .foregroundStyle(theme.color(.colorTextPlaceholder))
                .padding(.horizontal, theme.length(.spaceL))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: theme.length(.componentFieldHeight))
                .overlay(Capsule().strokeBorder(theme.color(.colorLineDivider), lineWidth: theme.length(.strokeHairline)))
        }
        .padding(theme.length(.spaceL))
        .frame(width: CGFloat(theme.geometry.assistantWidth))
        .background(theme.color(.colorBackgroundContainer))
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(theme.color(.colorLineDivider), lineWidth: theme.length(.strokeHairline)))
        .themeShadow(theme, .shadowFloating, radius: radius)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(theme.text("assistant.title"))
    }
}
