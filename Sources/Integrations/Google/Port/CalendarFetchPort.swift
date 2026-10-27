import Foundation

protocol CalendarFetchPort: Sendable {
    func listCalendars() async throws -> [EventCalendar]
    func upcomingEvents(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEvent]
}
