import Foundation

public enum DateLabel: Equatable, Sendable {
    case time(Date)
    case yesterday
    case weekday(Date)
    case day(Date)
    case none

    public static func of(_ date: Date?, now: Date, calendar: Calendar = .current) -> DateLabel {
        guard let date else { return .none }
        if calendar.isDate(date, inSameDayAs: now) { return .time(date) }
        if let before = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: before) {
            return .yesterday
        }
        let start = calendar.startOfDay(for: now)
        if let week = calendar.date(byAdding: .day, value: -6, to: start), date >= week, date < start {
            return .weekday(date)
        }
        return .day(date)
    }
}

public enum ThreadDate: Equatable, Sendable {
    case today(Date)
    case dated(Date, withYear: Bool)

    static func of(_ date: Date?, now: Date, calendar: Calendar = .current) -> ThreadDate? {
        guard let date else { return nil }
        if calendar.isDate(date, inSameDayAs: now) { return .today(date) }
        return .dated(date, withYear: calendar.component(.year, from: date) != calendar.component(.year, from: now))
    }
}
