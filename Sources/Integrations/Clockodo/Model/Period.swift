import Assistant
import Foundation

enum Period: String, CaseIterable, Sendable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    init(_ period: TimePeriod) {
        switch period {
        case .today: self = .today
        case .week: self = .week
        case .month: self = .month
        }
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }

    func span(now: Date, calendar: Calendar = Period.calendar) -> (since: Date, until: Date) {
        let since: Date
        switch self {
        case .today:
            since = calendar.startOfDay(for: now)
        case .week:
            since = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        case .month:
            since = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        }
        return (since, now)
    }
}
