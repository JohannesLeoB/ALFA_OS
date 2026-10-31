import Assistant
import Foundation

public struct TimeEntry: Identifiable, Sendable, Equatable {
    public let id: Int
    let customerID: Int
    let projectID: Int?
    let activityID: Int
    let text: String?
    let start: Date
    let seconds: Int
    let billable: Bool

    init(
        id: Int, customerID: Int, projectID: Int?, activityID: Int, text: String?, start: Date, seconds: Int,
        billable: Bool = true
    ) {
        self.id = id
        self.customerID = customerID
        self.projectID = projectID
        self.activityID = activityID
        self.text = text
        self.start = start
        self.seconds = seconds
        self.billable = billable
    }
}

public struct TimeProject: Hashable, Sendable, Identifiable {
    public let id: Int
    let customerID: Int
    let name: String
    let isActive: Bool

    init(id: Int, customerID: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.customerID = customerID
        self.name = name
        self.isActive = isActive
    }
}

public struct TimeCustomer: Hashable, Sendable, Identifiable {
    public let id: Int
    let name: String
    let isActive: Bool

    init(id: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}

public struct TimeActivity: Hashable, Sendable, Identifiable {
    public let id: Int
    let name: String
    let isActive: Bool

    init(id: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}

struct TimeSlice: Identifiable, Equatable, Sendable {
    enum Origin: Equatable, Sendable {
        case timer
        case manual
    }

    let id: UUID
    var projectNumber: String
    var projectTitle: String
    var costCenter: String
    var start: Date
    var end: Date
    var text: String
    var billable: Bool
    let origin: Origin
    let timerSeconds: Double?
    var customerID: Int?
    var projectID: Int?
    var activityID: Int?

    var seconds: Double { timerSeconds ?? max(0, end.timeIntervalSince(start)) }

    init(
        id: UUID = UUID(), projectNumber: String = "", projectTitle: String = "", costCenter: String = "",
        start: Date = Date(), end: Date = Date(), text: String = "", billable: Bool = true,
        origin: Origin = .manual, timerSeconds: Double? = nil,
        customerID: Int? = nil, projectID: Int? = nil, activityID: Int? = nil
    ) {
        self.id = id
        self.projectNumber = projectNumber
        self.projectTitle = projectTitle
        self.costCenter = costCenter
        self.start = start
        self.end = end
        self.text = text
        self.billable = billable
        self.origin = origin
        self.timerSeconds = timerSeconds
        self.customerID = customerID
        self.projectID = projectID
        self.activityID = activityID
    }
}

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

enum RequestFailure: Error, Equatable, Sendable {
    case notConnected
    case invalidResponse
    case http(Int)
    case decoding

    var detail: String {
        switch self {
        case .notConnected: "notConnected"
        case .invalidResponse: "invalidResponse"
        case .http(let code): "http \(code)"
        case .decoding: "decoding"
        }
    }
}
