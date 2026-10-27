import Foundation

struct CalendarClient: CalendarFetchPort {
    static let root = "https://www.googleapis.com/calendar/v3"
    static let primary = "primary"
    static let upcomingLimit = "20"
    static let calendarListLimit = "250"
    static let secondsPerDay: TimeInterval = 86_400

    let requests: RequestClient
    let clock: @Sendable () -> Date

    init(requests: RequestClient, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.requests = requests
        self.clock = clock
    }

    func listCalendars() async throws -> [EventCalendar] {
        let url = try RequestClient.url(Self.root + "/users/me/calendarList", query: [
            URLQueryItem(name: "minAccessRole", value: "reader"),
            URLQueryItem(name: "showHidden", value: "false"),
            URLQueryItem(name: "maxResults", value: Self.calendarListLimit),
        ])
        return try CalendarParser.calendars(from: try await requests.send(url))
    }

    func upcomingEvents(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEvent] {
        let id = calendarID ?? Self.primary
        let now = clock()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var items = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: formatter.string(from: now)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: now.addingTimeInterval(TimeInterval(withinDays) * Self.secondsPerDay))),
            URLQueryItem(name: "maxResults", value: Self.upcomingLimit),
        ]
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id
        let url = try RequestClient.url(Self.root + "/calendars/\(encoded)/events", query: items)
        return try CalendarParser.events(from: try await requests.send(url), calendarID: id)
    }
}
