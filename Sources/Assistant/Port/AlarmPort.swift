public protocol AlarmPort: Sendable {
    func reschedule(_ todo: Todo) async
    func cancel(todoID: String) async
}
