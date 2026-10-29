import Mail

extension InboxState {
    func extend(_ window: inout Int, total: Int) {
        if window < total {
            window += SheetValues.listWindowStep
        } else if listTail != nil {
            Task { await loadTail() }
        }
    }
}
