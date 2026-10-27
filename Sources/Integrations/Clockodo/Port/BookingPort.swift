import Foundation

protocol BookingPort: Sendable {
    func createEntry(
        customerID: Int, activityID: Int, projectID: Int?, since: Date, until: Date, billable: Bool, text: String?,
        confirmed: Bool
    ) async throws -> String
    func deleteEntry(id: Int, confirmed: Bool) async throws
    func updateText(id: Int, text: String, confirmed: Bool) async throws
    func setBillable(id: Int, billable: Bool, confirmed: Bool) async throws
}
