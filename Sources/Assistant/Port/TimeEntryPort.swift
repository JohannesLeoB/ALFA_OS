public protocol TimeEntryPort: Sendable {
    func report(period: TimePeriod) async -> TimeReport
}
