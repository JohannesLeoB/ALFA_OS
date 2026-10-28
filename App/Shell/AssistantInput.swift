import Assistant
import Design
import SwiftUI

struct AssistantInput: View {
    @Environment(\.appearance) private var appearance
    @Bindable var conversation: ChatState
    let off: Bool
    let files: Bool
    let attach: () -> Void
    let send: () -> Void
    let close: () -> Void
    @FocusState private var focused: Bool

    private var ready: Bool { !off && conversation.canSend }

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
            SymbolButton(help: appearance.string(files ? "shell.symbolButton.assistantAttach.tooltip" : "shell.symbolButton.assistantAttachOff.tooltip"),
                         glyph: .attach, dimmed: !files, tone: nil, hoverTone: nil, ringed: false, hover: .fill, hoverFill: \.inverseHot, pressed: false,
                         action: attach)
            ZStack(alignment: .leading) {
                if conversation.draft.isEmpty {
                    appearance.text("shell.assistantInput.field")
                        .lineLimit(1)
                        .opacity(SheetValues.placeholderOpacity)
                        .allowsHitTesting(false)
                }
                TextField("", text: $conversation.draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .disabled(off)
                    .onSubmit { send() }
                    .onKeyPress(.escape) {
                        close()
                        return .handled
                    }
                    .accessibilityLabel(appearance.text("shell.assistantInput.field"))
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step4))
            .frame(maxWidth: .infinity)
            SymbolButton(help: appearance.string("shell.symbolButton.assistantSend.tooltip"), glyph: .send, disabled: !ready, dimmed: false,
                         tone: ready ? \.inverse : \.onInverseTertiary, hoverTone: nil, ringed: false, plate: ready ? \.onInverse : nil, hover: .none,
                         pressed: false, action: send)
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step4))
        .padding(.trailing, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step40))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.inverseField)))
        .opacity(off ? Tokens.Opacity.disabled : 1)
        .task {
            try? await Task.sleep(for: .seconds(Tokens.Duration.toggle))
            focused = true
        }
    }
}
