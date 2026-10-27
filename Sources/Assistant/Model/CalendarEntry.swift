import Foundation

public struct CalendarEntry: Sendable, Equatable {
    public let id: String
    public let title: String
    public let startsAt: Date?
    public let isAllDay: Bool
    public let location: String?
    var calendarTitle: String

    public init(id: String, title: String, startsAt: Date?, isAllDay: Bool = false, location: String? = nil,
                calendarTitle: String = "") {
        self.id = id
        self.title = title
        self.startsAt = startsAt
        self.isAllDay = isAllDay
        self.location = location
        self.calendarTitle = calendarTitle
    }
}

public struct CalendarRef: Sendable, Equatable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}
