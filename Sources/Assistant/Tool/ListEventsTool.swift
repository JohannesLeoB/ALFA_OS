import Foundation

public struct ListEventsTool: ToolPort {
    static let maxCalendars = 12
    static let defaultDays = 14

    private let calendar: any CalendarPort

    public init(calendar: any CalendarPort) {
        self.calendar = calendar
    }

    public var name: String { "list_calendar_events" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .calendar }
    public var manifestID: String { "CALENDAR_LIST" }
    public var parameters: [ToolParameter] {
        [ToolParameter("query"), ToolParameter("within_days", kind: .integer)]
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.optionalText("query")
        let days = input.integer("within_days") ?? Self.defaultDays
        var teamFailed = false
        if calendar.hasTeamCalendars {
            do {
                let across = try await acrossCalendars(query: query, days: days)
                return result(across.entries, days: days, ownOnly: false, missing: across.missing)
            } catch PortFailure.notConnected {
                return .failure("assistant.calendar.notConnected")
            } catch {
                teamFailed = true
            }
        }
        do {
            let events = try await calendar.events(calendarID: nil, query: query, withinDays: days)
            return result(events, days: days, ownOnly: teamFailed)
        } catch PortFailure.notConnected {
            return .failure("assistant.calendar.notConnected")
        } catch {
            return .failure("assistant.calendar.failed", PortFailure.detail(of: error))
        }
    }

    private func result(_ events: [CalendarEntry], days: Int, ownOnly: Bool, missing: [String] = []) -> ToolResult {
        var lines: [Phrase] = events.isEmpty ? [.make("assistant.calendar.empty", String(days))] : events.map(Self.row)
        if ownOnly { lines += [.raw(""), .make("assistant.calendar.ownOnly")] }
        if !missing.isEmpty { lines += [.raw(""), .make("assistant.calendar.partial", missing.joined(separator: ", "))] }
        return ToolResult(lines: lines)
    }

    static func row(_ event: CalendarEntry) -> Phrase {
        let when: Phrase
        if let start = event.startsAt {
            when = event.isAllDay ? .make("assistant.calendar.allDay") : .raw(ListingEngine.dateTime(start))
        } else {
            when = .make("assistant.common.noDate")
        }
        var parts: [Phrase] = [.raw("\u{2022} \(event.title) \u{2014} "), when]
        if let place = event.location { parts.append(.raw(" @ \(place)")) }
        if event.calendarTitle.isEmpty == false { parts.append(.raw(" [\(event.calendarTitle)]")) }
        return .join(parts, "")
    }

    private func acrossCalendars(query: String?, days: Int) async throws -> (entries: [CalendarEntry], missing: [String]) {
        let calendars = try await calendar.calendars()
        let port = calendar
        var perCalendar: [[CalendarEntry]] = []
        var failure: (any Error)?
        var missing: [String] = []
        await withTaskGroup(of: (String, Result<[CalendarEntry], any Error>).self) { group in
            for ref in calendars.prefix(Self.maxCalendars) {
                group.addTask {
                    do {
                        let raw = try await port.events(calendarID: ref.id, query: query, withinDays: days)
                        return (ref.title, .success(raw.map { entry in
                            var copy = entry
                            copy.calendarTitle = ref.title
                            return copy
                        }))
                    } catch {
                        return (ref.title, .failure(error))
                    }
                }
            }
            for await (title, part) in group {
                switch part {
                case .success(let entries): perCalendar.append(entries)
                case .failure(let error):
                    failure = failure ?? error
                    missing.append(title)
                }
            }
        }
        if let failure, perCalendar.isEmpty { throw failure }
        return (Self.merge(perCalendar), missing.sorted())
    }

    static func merge(_ perCalendar: [[CalendarEntry]]) -> [CalendarEntry] {
        perCalendar.flatMap { $0 }.sorted { lhs, rhs in
            switch (lhs.startsAt, rhs.startsAt) {
            case let (left?, right?): return left == right ? lhs.id < rhs.id : left < right
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.id < rhs.id
            }
        }
    }
}

public struct ProposeEventTool: ToolPort {
    static let defaultMinutes = 60
    static let minimumMinutes = 5

    public init() {}

    public var name: String { "propose_termin" }
    public var access: ToolAccess { .propose }
    public var privacy: PrivacyCategory { .calendar }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] {
        [
            ToolParameter("titel", required: true), ToolParameter("start", required: true),
            ToolParameter("dauer", kind: .integer), ToolParameter("ort"), ToolParameter("notiz"),
            ToolParameter("gaeste"),
        ]
    }

    static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ListingEngine.timeZone
        return calendar
    }

    static func parse(_ raw: String) -> (start: Date, allDay: Bool)? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        func date(_ pattern: String) -> Date? {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = ListingEngine.timeZone
            formatter.dateFormat = pattern
            return formatter.date(from: text)
        }
        if let withTime = date("yyyy-MM-dd HH:mm") { return (withTime, false) }
        if let dayOnly = date("yyyy-MM-dd") { return (dayOnly, true) }
        return nil
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let title = input.text("titel")
        guard title.isEmpty == false else { return .failure("assistant.appointment.noTitle") }
        guard let parsed = Self.parse(input.text("start")) else { return .failure("assistant.appointment.badStart") }
        let minutes = input.integer("dauer") ?? Self.defaultMinutes
        let end: Date = parsed.allDay
            ? Self.calendar().date(byAdding: .day, value: 1, to: parsed.start) ?? parsed.start
            : parsed.start.addingTimeInterval(TimeInterval(max(minutes, Self.minimumMinutes) * 60))
        let guests = input.text("gaeste").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("@") }
        let draft = AppointmentDraft(title: title, start: parsed.start, end: end, allDay: parsed.allDay,
                                     location: input.optionalText("ort"), details: input.optionalText("notiz"), guests: guests)
        return ToolResult(.make("assistant.appointment.ready", title), cards: [.appointmentDraft(draft)])
    }
}

public struct SuggestEventLinkTool: ToolPort {
    public init() {}

    public var name: String { "suggest_calendar_event" }
    public var access: ToolAccess { .propose }
    public var privacy: PrivacyCategory { .calendar }
    public var manifestID: String { "CALENDAR_SUGGEST" }
    public var parameters: [ToolParameter] {
        [ToolParameter("title", required: true), ToolParameter("date"), ToolParameter("notes")]
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let title = input.text("title")
        guard title.isEmpty == false else { return .failure("assistant.event.noTitle") }
        var items = [URLQueryItem(name: "action", value: "TEMPLATE"), URLQueryItem(name: "text", value: title)]
        if let raw = input.optionalText("date"), let dates = Self.dates(from: raw) {
            items.append(URLQueryItem(name: "dates", value: dates))
        }
        if let notes = input.optionalText("notes") { items.append(URLQueryItem(name: "details", value: notes)) }
        var components = URLComponents(string: "https://calendar.google.com/calendar/render")
        components?.queryItems = items
        let url = components?.url?.absoluteString ?? "https://calendar.google.com/calendar/render?action=TEMPLATE"
        return ToolResult(.make("assistant.event.linkReady", title), cards: [.calendarLink(url: url)])
    }

    static func dates(from raw: String) -> String? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "T")
        let digits = cleaned.replacingOccurrences(of: "T", with: "")
        guard digits.allSatisfy(\.isNumber), digits.count >= 8 else { return nil }
        let day = String(digits.prefix(8))
        if digits.count >= 12 {
            var time = String(digits.dropFirst(8).prefix(6))
            while time.count < 6 { time += "0" }
            let start = "\(day)T\(time)"
            return "\(start)/\(start)"
        }
        return "\(day)/\(day)"
    }
}
