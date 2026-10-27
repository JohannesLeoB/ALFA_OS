import Foundation

protocol MasterDataPort: Sendable {
    func customers() async throws -> [TimeCustomer]
    func projects() async throws -> [TimeProject]
    func activities() async throws -> [TimeActivity]
    func entries(since: Date, until: Date, userID: Int?) async throws -> [TimeEntry]
}
