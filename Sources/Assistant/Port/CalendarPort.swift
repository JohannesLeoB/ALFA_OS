public protocol CalendarPort: Sendable {
    var hasTeamCalendars: Bool { get }
    func calendars() async throws -> [CalendarRef]
    func events(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEntry]
}
