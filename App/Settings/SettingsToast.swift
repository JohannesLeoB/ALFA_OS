import Hub
import SwiftUI

struct SettingsToast: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState

    var body: some View {
        if let key = state.toast {
            ToastView(message: state.toastName.map { Text(verbatim: appearance.format(key, $0)) } ?? appearance.text(key),
                      undoLabel: state.toastRetry == nil ? nil : appearance.text("settings.toast.retry"),
                      onUndo: state.toastRetry.map { retry in { state.dismissToast(); retry() } },
                      failed: state.toastFailed,
                      onDismiss: { state.dismissToast() })
                .id(state.toastSerial)
        }
    }
}
