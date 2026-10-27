import Foundation

enum ListingEngine {
    static let rowLimit = 40
    static let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current

    static func money(_ value: Double?) -> String? {
        guard let value else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSNumber)
    }

    static func wholeNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    static func format(_ date: Date, _ pattern: String, locale: String = "de_DE") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func day(_ date: Date) -> String { format(date, "dd.MM.yyyy") }

    static func shortDay(_ date: Date) -> String { format(date, "dd.MM.yy") }

    static func dateTime(_ date: Date) -> String { format(date, "EEE d. MMM yyyy, HH:mm") }

    static func clip(_ rows: [Phrase], total: Int) -> [Phrase] {
        guard total > rows.count else { return rows }
        return rows + [.make("assistant.list.more", String(total - rows.count))]
    }

    static func hours(_ seconds: Int) -> String {
        String(format: "%.1f", Double(seconds) / 3600)
    }

    static func duration(_ seconds: Int) -> String {
        if seconds >= 3600 { return String(format: "%.1f h", Double(seconds) / 3600) }
        return "\(Int((Double(seconds) / 60).rounded())) min"
    }
}
