import Foundation

enum DriveParser {
    private struct FileList: Decodable {
        var files: [Entry]
        var nextPageToken: String?
    }

    private struct DriveList: Decodable {
        var drives: [Shared]
        var nextPageToken: String?
    }

    private struct Shared: Decodable {
        var id: String
        var name: String
    }

    static func drives(from data: Data) throws -> (drives: [DriveFile], nextPageToken: String?) {
        guard let decoded = try? JSONDecoder().decode(DriveList.self, from: data) else { throw GoogleFailure.decodingFailed }
        return (decoded.drives.map { DriveFile(id: $0.id, name: $0.name, mimeType: DriveFile.folderMime) }, decoded.nextPageToken)
    }

    private struct Entry: Decodable {
        var id: String
        var name: String
        var mimeType: String
        var modifiedTime: String?
        var webViewLink: String?
        var size: String?
    }

    static func page(from data: Data) throws -> (files: [DriveFile], nextPageToken: String?) {
        guard let decoded = try? JSONDecoder().decode(FileList.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let files = decoded.files.map { entry in
            DriveFile(id: entry.id, name: entry.name, mimeType: entry.mimeType,
                      modifiedAt: entry.modifiedTime.flatMap { formatter.date(from: $0) },
                      webViewLink: entry.webViewLink, size: entry.size.flatMap { Int($0) })
        }
        return (files, decoded.nextPageToken)
    }

    static func file(from data: Data) throws -> DriveFile {
        guard let object = jsonObject(data),
              let id = object["id"] as? String,
              let name = object["name"] as? String,
              let mimeType = object["mimeType"] as? String else {
            throw GoogleFailure.decodingFailed
        }
        return DriveFile(id: id, name: name, mimeType: mimeType, modifiedAt: nil,
                         webViewLink: object["webViewLink"] as? String)
    }

    static func name(from data: Data) throws -> String {
        guard let object = jsonObject(data),
              let name = object["name"] as? String else { throw GoogleFailure.decodingFailed }
        return name
    }

    static func firstID(from data: Data) -> String? {
        guard let object = jsonObject(data),
              let files = object["files"] as? [[String: Any]] else { return nil }
        return files.first?["id"] as? String
    }

    static func id(from data: Data) throws -> String {
        guard let object = jsonObject(data),
              let id = object["id"] as? String else { throw GoogleFailure.decodingFailed }
        return id
    }

    private static func jsonObject(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

enum CalendarParser {
    private struct EventList: Decodable { var items: [EventEntry] }

    private struct EventEntry: Decodable {
        var id: String
        var summary: String?
        var location: String?
        var start: EventTime?
        var end: EventTime?
    }

    private struct EventTime: Decodable {
        var date: String?
        var dateTime: String?
    }

    private struct CalendarList: Decodable { var items: [CalendarItem] }

    private struct CalendarItem: Decodable {
        var id: String
        var summary: String?
        var summaryOverride: String?
    }

    static func events(from data: Data, calendarID: String) throws -> [CalendarEvent] {
        guard let decoded = try? JSONDecoder().decode(EventList.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        return decoded.items.map { entry in
            CalendarEvent(
                id: "\(calendarID)#\(entry.id)",
                title: entry.summary ?? "",
                startsAt: date(entry.start),
                endsAt: date(entry.end),
                isAllDay: entry.start?.dateTime == nil,
                location: entry.location,
                calendarID: calendarID)
        }
    }

    static func calendars(from data: Data) throws -> [EventCalendar] {
        guard let decoded = try? JSONDecoder().decode(CalendarList.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        return decoded.items.map { EventCalendar(id: $0.id, title: $0.summaryOverride ?? $0.summary ?? $0.id) }
    }

    private static func date(_ time: EventTime?) -> Date? {
        if let raw = time?.dateTime {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return fractional.date(from: raw) ?? plain.date(from: raw)
        }
        if let raw = time?.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.date(from: raw)
        }
        return nil
    }
}

enum ContactParser {
    private struct SearchResponse: Decodable { var results: [Result]? }

    private struct ListResponse: Decodable {
        var connections: [Person]?
        var nextPageToken: String?
    }

    private struct Result: Decodable { var person: Person? }

    private struct Person: Decodable {
        var resourceName: String?
        var names: [Name]?
        var emailAddresses: [Value]?
        var phoneNumbers: [Value]?
        var organizations: [Organization]?
    }

    private struct Name: Decodable { var displayName: String? }

    private struct Value: Decodable { var value: String? }

    private struct Organization: Decodable { var name: String? }

    static func contacts(from data: Data) throws -> [Contact] {
        guard let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        return (decoded.results ?? []).map { contact($0.person) }
    }

    static func page(from data: Data) throws -> (contacts: [Contact], next: String?) {
        guard let decoded = try? JSONDecoder().decode(ListResponse.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        let next = decoded.nextPageToken.flatMap { $0.isEmpty ? nil : $0 }
        return ((decoded.connections ?? []).map { contact($0) }, next)
    }

    private static func contact(_ person: Person?) -> Contact {
        Contact(
            id: person?.resourceName ?? UUID().uuidString,
            displayName: person?.names?.first?.displayName ?? "",
            email: person?.emailAddresses?.first?.value,
            phone: person?.phoneNumbers?.first?.value,
            organization: person?.organizations?.first?.name)
    }
}
