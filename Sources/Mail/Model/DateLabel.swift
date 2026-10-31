import Foundation

public enum DateLabel: Equatable, Sendable {
    case time(Date)
    case yesterday
    case weekday(Date)
    case upcoming(days: Int)
    case day(Date, withYear: Bool)
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
        if let first = calendar.date(byAdding: .day, value: 1, to: start), let last = calendar.date(byAdding: .day, value: Self.upcomingDays + 1, to: start),
           date >= first, date < last {
            return .upcoming(days: calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 1)
        }
        return .day(date, withYear: calendar.component(.year, from: date) != calendar.component(.year, from: now))
    }

    static let upcomingDays = 6
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
