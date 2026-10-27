import Foundation

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
