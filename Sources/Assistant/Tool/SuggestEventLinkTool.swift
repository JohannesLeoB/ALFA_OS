import Foundation

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
