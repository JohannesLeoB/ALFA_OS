import Assistant
import Design
import Shell
import SwiftUI

struct AssistantPanel: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance

    private var desk: DeskState { session.desk }

    var body: some View {
        let conversation = session.conversation
        let turns = conversation.turns
        let off = session.assistantOff
        let room = CGFloat(desk.blob.menuRoom(window: desk.window, measure: desk.measure)
            - Tokens.Spacing.step40 - Tokens.Spacing.step28 - Tokens.Spacing.step44)
        VStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Rectangle()
                .fill(appearance.color(\.inverseLine))
                .frame(height: CGFloat(Tokens.Size.hairline))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
            if !turns.isEmpty {
                AssistantThread(turns: turns, room: room, retry: session.retryAssistant)
            }
            if !off && (turns.isEmpty || session.claudeFailed) {
                appearance.text(session.assistantHintKey)
                    .foregroundStyle(appearance.color(\.onInverseTertiary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if off {
                offCard
            }
            AssistantScope(scope: conversation.scope, clearable: !turns.isEmpty, clear: conversation.clear)
            if !conversation.pending.isEmpty {
                ChipWrapLayout(gap: CGFloat(Tokens.Spacing.step8)) {
                    ForEach(conversation.pending) { pending in
                        AssistantAttachment(name: pending.file.fileName) { conversation.removePending(pending.id) }
                    }
                }
                .padding(.horizontal, CGFloat(Tokens.Spacing.step4))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            AssistantInput(conversation: conversation, off: off, files: session.assistantFiles,
                           attach: session.attachToAssistant, send: session.askAssistant, close: desk.close)
        }
        .typeStyle(Tokens.TextStyle.body)
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .padding(.bottom, CGFloat(Tokens.Spacing.step8))
        .onAppear { session.seeAssistant() }
    }

    private var offCard: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            appearance.text("shell.assistantCard.off")
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if session.assistantOffersSettings {
                TextButton(label: appearance.text("shell.textButton.assistantOff.text"), kind: .inverse, plate: \.inverseHot,
                           action: session.openAssistantSettings)
            }
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.inverseField)))
    }
}
