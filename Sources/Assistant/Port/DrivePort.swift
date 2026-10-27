public protocol DrivePort: Sendable {
    func list(folderID: String) async throws -> [DriveEntry]
    func offers(folderID: String) async throws -> OfferListing
    func findFile(named name: String, in folderID: String) async throws -> DriveEntry?
    func text(of file: DriveEntry) async throws -> String?
}
