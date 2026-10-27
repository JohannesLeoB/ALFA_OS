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
                return result(try await acrossCalendars(query: query, days: days), days: days, ownOnly: false)
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

    private func result(_ events: [CalendarEntry], days: Int, ownOnly: Bool) -> ToolResult {
        var lines: [Phrase] = events.isEmpty ? [.make("assistant.calendar.empty", String(days))] : events.map(Self.row)
        if ownOnly { lines += [.raw(""), .make("assistant.calendar.ownOnly")] }
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

    private func acrossCalendars(query: String?, days: Int) async throws -> [CalendarEntry] {
        let calendars = try await calendar.calendars()
        let port = calendar
        var perCalendar: [[CalendarEntry]] = []
        await withTaskGroup(of: [CalendarEntry].self) { group in
            for ref in calendars.prefix(Self.maxCalendars) {
                group.addTask {
                    let raw = (try? await port.events(calendarID: ref.id, query: query, withinDays: days)) ?? []
                    return raw.map { entry in
                        var copy = entry
                        copy.calendarTitle = ref.title
                        return copy
                    }
                }
            }
            for await part in group { perCalendar.append(part) }
        }
        return Self.merge(perCalendar)
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
