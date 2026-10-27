import Foundation

struct CalendarEvent: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var startsAt: Date?
    var endsAt: Date?
    var isAllDay: Bool
    var location: String?
    var calendarID: String
}

struct EventCalendar: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
}
