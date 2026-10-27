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
