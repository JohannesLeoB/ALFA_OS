import Mail
import SwiftUI

struct MailToast: View {
    @Environment(\.appearance) private var appearance
    let inbox: InboxState

    var body: some View {
        if let toast = inbox.toast {
            ToastView(message: text(toast), undoLabel: toast.undoable ? appearance.text("mail.toast.undo") : nil,
                      onUndo: toast.undoable ? { Task { await inbox.undoToast() } } : nil,
                      onDismiss: { inbox.dismissToast(toast.serial) })
                .id(toast.serial)
        }
    }

    private func text(_ toast: Toast) -> Text {
        if let count = toast.kind.count { return Text(verbatim: appearance.format(toast.kind.key, String(count))) }
        if let name = toast.kind.name { return Text(verbatim: appearance.format(toast.kind.key, name)) }
        return appearance.text(toast.kind.key)
    }
}
