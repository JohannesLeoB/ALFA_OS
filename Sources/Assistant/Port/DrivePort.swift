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
