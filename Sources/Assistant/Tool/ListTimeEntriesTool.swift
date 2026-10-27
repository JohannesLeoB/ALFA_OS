public struct ListTimeEntriesTool: ToolPort {
    private let time: any TimeEntryPort

    public init(time: any TimeEntryPort) {
        self.time = time
    }

    public var name: String { "list_zeiten" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .time }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("zeitraum")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let period = TimePeriod(rawValue: input.text("zeitraum").lowercased()) ?? .week
        let report = await time.report(period: period)
        if report.entries.isEmpty, let error = report.error { return .failure("assistant.time.error", error) }
        guard report.entries.isEmpty == false else {
            return ToolResult(.make("assistant.time.none", period.rawValue))
        }
        let total = report.entries.reduce(0) { $0 + $1.seconds }
        let rows: [Phrase] = report.entries.prefix(ListingEngine.rowLimit).map { entry in
            var text = "\u{2022} \(ListingEngine.day(entry.start)) | \(entry.customer) | \(entry.service) | \(ListingEngine.duration(entry.seconds))"
            if let note = entry.note, note.isEmpty == false { text += " | \(note)" }
            return .raw(text)
        }
        return ToolResult(lines: [.make("assistant.time.header." + period.rawValue, ListingEngine.hours(total))]
            + ListingEngine.clip(rows, total: report.entries.count))
    }
}
