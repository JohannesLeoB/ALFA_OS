import Foundation

enum CalendarParser {
    private struct EventList: Decodable { var items: [EventEntry] }

    private struct EventEntry: Decodable {
        var id: String
        var summary: String?
        var location: String?
        var start: EventTime?
        var end: EventTime?
    }

    private struct EventTime: Decodable {
        var date: String?
        var dateTime: String?
    }

    private struct CalendarList: Decodable { var items: [CalendarItem] }

    private struct CalendarItem: Decodable {
        var id: String
        var summary: String?
        var summaryOverride: String?
    }

    static func events(from data: Data, calendarID: String) throws -> [CalendarEvent] {
        guard let decoded = try? JSONDecoder().decode(EventList.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        return decoded.items.map { entry in
            CalendarEvent(
                id: "\(calendarID)#\(entry.id)",
                title: entry.summary ?? "",
                startsAt: date(entry.start),
                endsAt: date(entry.end),
                isAllDay: entry.start?.dateTime == nil,
                location: entry.location,
                calendarID: calendarID)
        }
    }

    static func calendars(from data: Data) throws -> [EventCalendar] {
        guard let decoded = try? JSONDecoder().decode(CalendarList.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        return decoded.items.map { EventCalendar(id: $0.id, title: $0.summaryOverride ?? $0.summary ?? $0.id) }
    }

    private static func date(_ time: EventTime?) -> Date? {
        if let raw = time?.dateTime {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return fractional.date(from: raw) ?? plain.date(from: raw)
        }
        if let raw = time?.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.date(from: raw)
        }
        return nil
    }
}
