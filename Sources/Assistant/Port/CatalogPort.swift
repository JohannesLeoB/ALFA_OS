import Foundation

public protocol CatalogPort: Sendable {
    func search(term: String, limit: Int) async -> ArticleSearchState
}

public protocol StockPort: Sendable {
    func current() async -> StockListState
}

protocol SamplePort: Sendable {
    func samples(projectNumber: String) async throws -> SampleListing
}

public protocol ShipmentPort: Sendable {
    func track(number: String) async throws -> ShipmentStatus
}

public protocol ReceiptPort: Sendable {
    func receipts() async -> [ReceiptEntry]
}

public protocol TimeEntryPort: Sendable {
    func report(period: TimePeriod) async -> TimeReport
}

public protocol TaskBoardPort: Sendable {
    func openTasks(listID: String) async throws -> [TaskItem]
    func members(listID: String) async throws -> [TaskMember]
}

protocol ArtifactPort: Sendable {
    @discardableResult
    func write(_ data: Data, name: String, at date: Date) throws -> URL
}

public protocol DrivePort: Sendable {
    func list(folderID: String) async throws -> [DriveEntry]
    func offers(folderID: String) async throws -> OfferListing
    func findFile(named name: String, in folderID: String) async throws -> DriveEntry?
    func text(of file: DriveEntry) async throws -> String?
}

public protocol CalendarPort: Sendable {
    var hasTeamCalendars: Bool { get }
    func calendars() async throws -> [CalendarRef]
    func events(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEntry]
}

public protocol MailSearchPort: Sendable {
    func search(query: String, limit: Int) async throws -> [MailHit]
    func body(messageID: String) async throws -> String
}

public protocol GoogleContactsPort: Sendable {
    func search(query: String) async throws -> [GoogleContact]
}
