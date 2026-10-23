import ShellCore
import SwiftUI

struct ClaudeEntry: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel
    @State private var key = ""
    @State private var name = ""
    @State private var editing = false

    var body: some View {
        if let stored = model.claudeModel, !editing {
            Labeled(key: "dock.state.connected") {
                Text(verbatim: stored)
                    .font(style.font(Design.TextSize.small))
                    .foregroundStyle(style.color(\.inkTertiary))
                    .lineLimit(1)
                Pill(key: "draws.claude.change") {
                    name = stored
                    editing = true
                }
            }
        } else {
            form
        }
    }

    private var form: some View {
        let ready = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            FieldRow(label: word("draws.claude.key"), value: $key, needed: false, secret: true)
            FieldRow(label: word("draws.claude.model"), value: $name, needed: false)
            HStack {
                Spacer(minLength: 0)
                Pill(key: "draws.claude.save", accent: true) {
                    if model.saveClaude(key: key, name: name) {
                        key = ""
                        name = ""
                        editing = false
                    }
                }
                .opacity(ready ? 1 : SheetValues.disabledOpacity)
                .allowsHitTesting(ready)
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .padding(.vertical, CGFloat(Design.Spacing.step4))
        }
        .onDisappear { key = "" }
    }
}
