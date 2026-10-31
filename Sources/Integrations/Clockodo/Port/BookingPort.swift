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

protocol MasterDataPort: Sendable {
    func customers() async throws -> [TimeCustomer]
    func projects() async throws -> [TimeProject]
    func activities() async throws -> [TimeActivity]
    func entries(since: Date, until: Date, userID: Int?) async throws -> [TimeEntry]
}

public protocol CredentialsPort: Sendable {
    func load() throws -> Credentials?
}
