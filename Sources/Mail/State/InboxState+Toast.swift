extension InboxState {
    func post(_ kind: ToastKind, undo: (@MainActor () async -> Void)? = nil) {
        toastSerial += 1
        toast = Toast(serial: toastSerial, kind: kind, undoable: undo != nil)
        undoAction = undo
    }

    public func announce(_ kind: ToastKind) {
        post(kind)
    }

    public func dismissToast(_ serial: Int) {
        guard toast?.serial == serial else { return }
        toast = nil
        undoAction = nil
    }

    public func undoToast() async {
        let action = undoAction
        toast = nil
        undoAction = nil
        await action?()
    }
}
