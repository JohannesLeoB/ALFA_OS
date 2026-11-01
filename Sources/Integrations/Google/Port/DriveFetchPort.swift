import Foundation

protocol DriveFetchPort: Sendable {
    func listFolder(folderID: String) async throws -> [DriveFile]
    func listDrives() async throws -> [DriveFile]
    func fileName(of fileID: String) async throws -> String
    func downloadContent(fileID: String) async throws -> Data
    func exportFile(fileID: String, exportMimeType: String) async throws -> Data
    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String
    func uploadFile(name: String, mimeType: String, data: Data, parentFolderID: String) async throws -> DriveFile
}

protocol CalendarFetchPort: Sendable {
    func listCalendars() async throws -> [EventCalendar]
    func upcomingEvents(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEvent]
}

protocol ContactsFetchPort: Sendable {
    func searchContacts(query: String?) async throws -> [Contact]
    func allContacts() async throws -> [Contact]
}
