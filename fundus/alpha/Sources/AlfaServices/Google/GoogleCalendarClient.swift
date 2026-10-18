import Foundation

public struct GoogleCalendarEvent: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var startsAt: Date?

    public var endsAt: Date?
    public var isAllDay: Bool
    public var location: String?

    public var calendarID: String
    public var calendarTitle: String

    public init(id: String, title: String, startsAt: Date?, isAllDay: Bool, location: String?,
                endsAt: Date? = nil,
                calendarID: String = "primary", calendarTitle: String = "") {
        self.id = id
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isAllDay = isAllDay
        self.location = location
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
    }
}

public struct GoogleCalendar: Identifiable, Equatable, Sendable {
    public var id: String
    public var summary: String
    public var isPrimary: Bool

    public var backgroundColorHex: String?

    public var accessRole: String

    public init(id: String, summary: String, isPrimary: Bool,
                backgroundColorHex: String? = nil, accessRole: String = "reader") {
        self.id = id
        self.summary = summary
        self.isPrimary = isPrimary
        self.backgroundColorHex = backgroundColorHex
        self.accessRole = accessRole
    }
}

public enum GoogleCalendarError: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed
}

public protocol GoogleCalendarFetching: Sendable {
    func listUpcomingEvents(query: String?, withinDays: Int) async throws -> [GoogleCalendarEvent]
}

public protocol GoogleCalendarTeamFetching: Sendable {
    func listCalendars() async throws -> [GoogleCalendar]

    func listUpcomingEvents(calendarID: String, query: String?, withinDays: Int) async throws -> [GoogleCalendarEvent]

    func listEvents(calendarID: String, query: String?, from: Date, to: Date) async throws -> [GoogleCalendarEvent]
}

public struct GoogleCalendarNeuerTermin: Sendable {
    public var title: String
    public var start: Date
    public var ende: Date
    public var ganztaegig: Bool
    public var ort: String?
    public var beschreibung: String?
    public var gaeste: [String]
    public var erinnerungMinuten: Int?
    public var calendarID: String

    public init(title: String, start: Date, ende: Date, ganztaegig: Bool = false,
                ort: String? = nil, beschreibung: String? = nil, gaeste: [String] = [],
                erinnerungMinuten: Int? = 30, calendarID: String = "primary") {
        self.title = title; self.start = start; self.ende = ende
        self.ganztaegig = ganztaegig; self.ort = ort; self.beschreibung = beschreibung
        self.gaeste = gaeste; self.erinnerungMinuten = erinnerungMinuten; self.calendarID = calendarID
    }
}

public protocol GoogleCalendarWriting: Sendable {
    func createEvent(_ appointment: GoogleCalendarNeuerTermin) async throws -> GoogleCalendarEvent
}

public struct GoogleCalendarClient: GoogleCalendarFetching {
    private let tokenProvider: GoogleAccessTokenProviding
    private let session: URLSession
    private let baseURL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"

    public init(
        tokenProvider: GoogleAccessTokenProviding = GoogleAccessTokenProvider(),
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
    }

    public func listUpcomingEvents(query: String?, withinDays: Int = 14) async throws -> [GoogleCalendarEvent] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleCalendarError.notConnected
        }
        guard let url = Self.buildListEventsURL(query: query, withinDays: withinDays, baseURL: baseURL, now: Date()) else {
            throw GoogleCalendarError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleCalendarError.httpError(http.statusCode) }

        return try Self.parseEvents(from: data)
    }

    static func buildListEventsURL(query: String?, withinDays: Int, baseURL: String, now: Date) -> URL? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let timeMax = now.addingTimeInterval(TimeInterval(withinDays) * 86_400)

        var queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: isoFormatter.string(from: now)),
            URLQueryItem(name: "timeMax", value: isoFormatter.string(from: timeMax)),
            URLQueryItem(name: "maxResults", value: "20")
        ]
        if let query, query.isEmpty == false {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }

        var components = URLComponents(string: baseURL)
        components?.queryItems = queryItems
        return components?.url
    }

    static func buildRangeEventsURL(query: String?, from: Date, to: Date, baseURL: String, maxResults: Int = 250) -> URL? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        var queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: isoFormatter.string(from: from)),
            URLQueryItem(name: "timeMax", value: isoFormatter.string(from: to)),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        if let query, query.isEmpty == false {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }

        var components = URLComponents(string: baseURL)
        components?.queryItems = queryItems
        return components?.url
    }

    static func parseEvents(from data: Data,
                            calendarID: String = "primary",
                            calendarTitle: String = "") throws -> [GoogleCalendarEvent] {
        do {
            let decoded = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data)
            let dateTimeFormatter = ISO8601DateFormatter()
            dateTimeFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateTimeFormatterNoFraction = ISO8601DateFormatter()
            dateTimeFormatterNoFraction.formatOptions = [.withInternetDateTime]
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")

            func parse(_ dt: GoogleCalendarEventDateTime?) -> Date? {
                if let raw = dt?.dateTime {
                    return dateTimeFormatter.date(from: raw) ?? dateTimeFormatterNoFraction.date(from: raw)
                } else if let raw = dt?.date {
                    return dateOnlyFormatter.date(from: raw)
                }
                return nil
            }
            return decoded.items.map { entry in
                let isAllDay = entry.start?.dateTime == nil
                return GoogleCalendarEvent(
                    id: "\(calendarID)#\(entry.id)",
                    title: entry.summary ?? "(ohne Titel)",
                    startsAt: parse(entry.start),
                    isAllDay: isAllDay,
                    location: entry.location,
                    endsAt: parse(entry.end),
                    calendarID: calendarID,
                    calendarTitle: calendarTitle
                )
            }
        } catch {
            throw GoogleCalendarError.decodingFailed
        }
    }

    static func eventsBaseURL(calendarID: String) -> String {
        let encoded = calendarID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? calendarID
        return "https://www.googleapis.com/calendar/v3/calendars/\(encoded)/events"
    }

    static func buildCalendarListURL() -> URL? {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")
        components?.queryItems = [
            URLQueryItem(name: "minAccessRole", value: "reader"),
            URLQueryItem(name: "showHidden", value: "false"),
            URLQueryItem(name: "maxResults", value: "250")
        ]
        return components?.url
    }

    static func parseCalendars(from data: Data) throws -> [GoogleCalendar] {
        do {
            let decoded = try JSONDecoder().decode(GoogleCalendarListItemsResponse.self, from: data)
            return decoded.items.map {
                GoogleCalendar(
                    id: $0.id,
                    summary: $0.summaryOverride ?? $0.summary ?? $0.id,
                    isPrimary: $0.primary ?? false,
                    backgroundColorHex: $0.backgroundColor,
                    accessRole: $0.accessRole ?? "reader"
                )
            }
        } catch {
            throw GoogleCalendarError.decodingFailed
        }
    }

    public static func mergeAndSort(_ perCalendar: [[GoogleCalendarEvent]]) -> [GoogleCalendarEvent] {
        perCalendar.flatMap { $0 }.sorted { a, b in
            switch (a.startsAt, b.startsAt) {
            case let (x?, y?): return x == y ? a.id < b.id : x < y
            case (nil, _?):    return false
            case (_?, nil):    return true
            case (nil, nil):   return a.id < b.id
            }
        }
    }
}

private struct GoogleCalendarListResponse: Decodable {
    var items: [GoogleCalendarEventEntry]
}

private struct GoogleCalendarEventEntry: Decodable {
    var id: String
    var summary: String?
    var location: String?
    var start: GoogleCalendarEventDateTime?
    var end: GoogleCalendarEventDateTime?
}

private struct GoogleCalendarEventDateTime: Decodable {
    var date: String?
    var dateTime: String?
}

private struct GoogleCalendarListItemsResponse: Decodable {
    var items: [GoogleCalendarListItem]
}

private struct GoogleCalendarListItem: Decodable {
    var id: String
    var summary: String?
    var summaryOverride: String?
    var primary: Bool?
    var backgroundColor: String?
    var accessRole: String?
}

extension GoogleCalendarClient: GoogleCalendarTeamFetching {
    public func listCalendars() async throws -> [GoogleCalendar] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleCalendarError.notConnected
        }
        guard let url = Self.buildCalendarListURL() else { throw GoogleCalendarError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleCalendarError.httpError(http.statusCode) }
        return try Self.parseCalendars(from: data)
    }

    public func listUpcomingEvents(calendarID: String, query: String?, withinDays: Int) async throws -> [GoogleCalendarEvent] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleCalendarError.notConnected
        }
        let base = Self.eventsBaseURL(calendarID: calendarID)
        guard let url = Self.buildListEventsURL(query: query, withinDays: withinDays, baseURL: base, now: Date()) else {
            throw GoogleCalendarError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleCalendarError.httpError(http.statusCode) }
        return try Self.parseEvents(from: data, calendarID: calendarID)
    }

    public func listEvents(calendarID: String, query: String?, from: Date, to: Date) async throws -> [GoogleCalendarEvent] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleCalendarError.notConnected
        }
        let base = Self.eventsBaseURL(calendarID: calendarID)
        guard let url = Self.buildRangeEventsURL(query: query, from: from, to: to, baseURL: base) else {
            throw GoogleCalendarError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleCalendarError.httpError(http.statusCode) }
        return try Self.parseEvents(from: data, calendarID: calendarID)
    }
}

extension GoogleCalendarClient: GoogleCalendarWriting {
    public func createEvent(_ appointment: GoogleCalendarNeuerTermin) async throws -> GoogleCalendarEvent {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleCalendarError.notConnected
        }
        let base = Self.eventsBaseURL(calendarID: appointment.calendarID)
        var components = URLComponents(string: base)
        if appointment.gaeste.isEmpty == false {
            components?.queryItems = [URLQueryItem(name: "sendUpdates", value: "all")]
        }
        guard let url = components?.url else { throw GoogleCalendarError.invalidResponse }

        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
        let tagesFormatter = DateFormatter()
        tagesFormatter.dateFormat = "yyyy-MM-dd"; tagesFormatter.timeZone = TimeZone.current

        var body: [String: Any] = ["summary": appointment.title]
        if let ort = appointment.ort, ort.isEmpty == false { body["location"] = ort }
        if let b = appointment.beschreibung, b.isEmpty == false { body["description"] = b }
        if appointment.ganztaegig {
            body["start"] = ["date": tagesFormatter.string(from: appointment.start)]
            body["end"]   = ["date": tagesFormatter.string(from: appointment.ende)]
        } else {
            body["start"] = ["dateTime": iso.string(from: appointment.start), "timeZone": TimeZone.current.identifier]
            body["end"]   = ["dateTime": iso.string(from: appointment.ende), "timeZone": TimeZone.current.identifier]
        }
        if appointment.gaeste.isEmpty == false {
            body["attendees"] = appointment.gaeste.map { ["email": $0] }
        }
        if let minuten = appointment.erinnerungMinuten {
            body["reminders"] = ["useDefault": false,
                                 "overrides": [["method": "popup", "minutes": minuten]]]
        } else {
            body["reminders"] = ["useDefault": true]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleCalendarError.httpError(http.statusCode) }
        return try Self.parseSingleEvent(from: data, calendarID: appointment.calendarID)
    }

    static func parseSingleEvent(from data: Data, calendarID: String) throws -> GoogleCalendarEvent {
        do {
            let entry = try JSONDecoder().decode(GoogleCalendarEventEntry.self, from: data)
            let dtf = ISO8601DateFormatter(); dtf.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dtf2 = ISO8601DateFormatter(); dtf2.formatOptions = [.withInternetDateTime]
            let donly = DateFormatter(); donly.dateFormat = "yyyy-MM-dd"; donly.timeZone = TimeZone(identifier: "UTC")
            func parse(_ dt: GoogleCalendarEventDateTime?) -> Date? {
                if let raw = dt?.dateTime { return dtf.date(from: raw) ?? dtf2.date(from: raw) }
                if let raw = dt?.date { return donly.date(from: raw) }
                return nil
            }
            return GoogleCalendarEvent(
                id: "\(calendarID)#\(entry.id)",
                title: entry.summary ?? "(ohne Titel)",
                startsAt: parse(entry.start),
                isAllDay: entry.start?.dateTime == nil,
                location: entry.location,
                endsAt: parse(entry.end),
                calendarID: calendarID)
        } catch {
            throw GoogleCalendarError.decodingFailed
        }
    }
}
