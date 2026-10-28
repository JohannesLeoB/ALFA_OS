import Assistant
import SwiftUI

struct AssistantToast: View {
    @Environment(\.appearance) private var appearance
    let conversation: ChatState

    var body: some View {
        if let note = conversation.note {
            switch note {
            case .cleared:
                ToastView(message: appearance.text("shell.assistantThread.cleared"), undoLabel: appearance.text("mail.toast.undo"),
                          onUndo: conversation.undo, onDismiss: conversation.dismiss)
                    .id(conversation.noteSerial)
            case .rejected(let failure):
                ToastView(message: Text(verbatim: message(failure)), failed: true, onDismiss: conversation.dismiss)
                    .id(conversation.noteSerial)
            }
        }
    }

    private func message(_ failure: AttachmentStore.Failure) -> String {
        switch failure {
        case .unsupported(let name): appearance.format("shell.assistantAttachment.unsupported", name)
        case .tooLarge(let name): appearance.format("shell.assistantAttachment.tooLarge", name)
        case .unreadable(let name): appearance.format("shell.assistantAttachment.unreadable", name)
        }
    }
}
