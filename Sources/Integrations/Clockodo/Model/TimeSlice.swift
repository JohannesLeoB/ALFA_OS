import Foundation

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
