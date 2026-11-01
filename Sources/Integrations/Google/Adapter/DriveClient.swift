import Assistant
import Foundation
import PDFKit

struct DriveClient: DriveFetchPort {
    static let filesEndpoint = "https://www.googleapis.com/drive/v3/files"
    static let uploadEndpoint = "https://www.googleapis.com/upload/drive/v3/files"
    static let drivesEndpoint = "https://www.googleapis.com/drive/v3/drives"
    static let listFields = "nextPageToken,files(id,name,mimeType,modifiedTime,webViewLink,size)"
    static let maxPages = 20
    static let pageSize = "100"

    let requests: RequestClient
    let forbiddenFolderIDs: Set<String>

    init(requests: RequestClient, forbiddenFolderIDs: Set<String>) {
        self.requests = requests
        self.forbiddenFolderIDs = forbiddenFolderIDs
    }

    func listFolder(folderID: String) async throws -> [DriveFile] {
        var all: [DriveFile] = []
        var pageToken: String?
        for _ in 0..<Self.maxPages {
            var items = [
                URLQueryItem(name: "q", value: "'\(folderID)' in parents and trashed=false"),
                URLQueryItem(name: "fields", value: Self.listFields),
                URLQueryItem(name: "pageSize", value: Self.pageSize),
                URLQueryItem(name: "orderBy", value: "folder,name"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true"),
            ]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let page = try DriveParser.page(from: try await requests.send(RequestClient.url(Self.filesEndpoint, query: items)))
            all += page.files
            guard let next = page.nextPageToken else { break }
            pageToken = next
        }
        return all
    }

    func listDrives() async throws -> [DriveFile] {
        var all: [DriveFile] = []
        var pageToken: String?
        for _ in 0..<Self.maxPages {
            var items = [URLQueryItem(name: "pageSize", value: Self.pageSize),
                         URLQueryItem(name: "fields", value: "nextPageToken,drives(id,name)")]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let page = try DriveParser.drives(from: try await requests.send(RequestClient.url(Self.drivesEndpoint, query: items)))
            all += page.drives
            guard let next = page.nextPageToken else { break }
            pageToken = next
        }
        return all
    }

    func fileName(of fileID: String) async throws -> String {
        let url = try RequestClient.url(Self.filesEndpoint + "/\(fileID)", query: [
            URLQueryItem(name: "fields", value: "name"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
        ])
        return try DriveParser.name(from: try await requests.send(url))
    }

    func downloadContent(fileID: String) async throws -> Data {
        try await requests.send(RequestClient.url(Self.filesEndpoint + "/\(fileID)", query: [
            URLQueryItem(name: "alt", value: "media"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
        ]))
    }

    func exportFile(fileID: String, exportMimeType: String) async throws -> Data {
        try await requests.send(RequestClient.url(Self.filesEndpoint + "/\(fileID)/export", query: [
            URLQueryItem(name: "mimeType", value: exportMimeType),
        ]))
    }

    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String {
        if let existing = try await findSubfolder(parentID: parentID, name: name) { return existing }
        let url = try RequestClient.url(Self.filesEndpoint, query: [
            URLQueryItem(name: "fields", value: "id"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
        ])
        let metadata: [String: Any] = ["name": name, "mimeType": DriveFile.folderMime, "parents": [parentID]]
        return try DriveParser.id(from: try await requests.send(url, method: "POST", json: metadata))
    }

    private func findSubfolder(parentID: String, name: String) async throws -> String? {
        let parent = parentID.replacingOccurrences(of: "'", with: "\\'")
        let escaped = name.replacingOccurrences(of: "'", with: "\\'")
        let query = "'\(parent)' in parents and name='\(escaped)' and mimeType='\(DriveFile.folderMime)' and trashed=false"
        let url = try RequestClient.url(Self.filesEndpoint, query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "files(id,name)"),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "includeItemsFromAllDrives", value: "true"),
        ])
        return DriveParser.firstID(from: try await requests.send(url))
    }

    func uploadFile(name: String, mimeType: String, data: Data, parentFolderID: String) async throws -> DriveFile {
        guard !forbiddenFolderIDs.contains(parentFolderID) else {
            throw GoogleFailure.uploadDestinationForbidden(parentFolderID)
        }
        let url = try RequestClient.url(Self.uploadEndpoint, query: [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "fields", value: "id,name,mimeType,webViewLink"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
        ])
        let metadata = try JSONSerialization.data(withJSONObject: ["name": name, "parents": [parentFolderID]])
        let boundary = "part_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
        body.append(metadata)
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let answer = try await requests.send(url, method: "POST", body: body,
                                             contentType: "multipart/related; boundary=\(boundary)")
        return try DriveParser.file(from: answer)
    }
}

struct DriveListingClient: Assistant.DrivePort {
    let drive: any DriveFetchPort
    let reader: DriveTextClient
    let convention: OfferConvention

    init(drive: any DriveFetchPort, offers: OfferConvention) {
        self.drive = drive
        self.reader = DriveTextClient(drive: drive)
        self.convention = offers
    }

    func list(folderID: String) async throws -> [DriveEntry] {
        do {
            return try await drive.listFolder(folderID: folderID).map(Self.entry)
        } catch {
            throw GoogleFailureEngine.port(error)
        }
    }

    func offers(folderID: String) async throws -> OfferListing {
        do {
            let result = try await OfferScanEngine.load(rootFolderID: folderID, drive: drive, convention: convention)
            return OfferListing(outgoing: result.outgoing.map(Self.offer), incoming: result.incoming.map(Self.offer))
        } catch {
            throw GoogleFailureEngine.port(error)
        }
    }

    func findFile(named name: String, in folderID: String) async throws -> DriveEntry? {
        do {
            return try await reader.findFile(named: name, in: folderID).map(Self.entry)
        } catch {
            throw GoogleFailureEngine.port(error)
        }
    }

    func text(of file: DriveEntry) async throws -> String? {
        do {
            return try await reader.text(of: DriveFile(id: file.id, name: file.name, mimeType: file.mimeType,
                                                     modifiedAt: file.modifiedAt, webViewLink: file.webViewLink))
        } catch {
            throw GoogleFailureEngine.port(error)
        }
    }

    static func entry(_ file: DriveFile) -> DriveEntry {
        DriveEntry(id: file.id, name: file.name, mimeType: file.mimeType, isFolder: file.isFolder,
                   typeLabel: file.typeLabel, modifiedAt: file.modifiedAt, webViewLink: file.webViewLink)
    }

    static func offer(_ classified: ClassifiedOffer) -> OfferListing.Offer {
        OfferListing.Offer(file: entry(classified.file), typeLabel: classified.type.labelKey,
                           documentNumber: classified.documentNumber)
    }
}

struct DriveTextClient: Sendable {
    static let maxCharacters = 400_000
    static let maxDepth = 4
    static let truncationMark = "\n\u{2026}"

    let drive: any DriveFetchPort

    func findFile(named query: String, in rootFolderID: String) async throws -> DriveFile? {
        let needle = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        var frontier: [(id: String, depth: Int)] = [(rootFolderID, 0)]
        while !frontier.isEmpty {
            let (id, depth) = frontier.removeFirst()
            let children = try await drive.listFolder(folderID: id)
            if let hit = children.first(where: { !$0.isFolder && $0.name.lowercased().contains(needle) }) { return hit }
            if depth < Self.maxDepth {
                for child in children where child.isFolder { frontier.append((child.id, depth + 1)) }
            }
        }
        return nil
    }

    func text(of file: DriveFile) async throws -> String? {
        let raw: String?
        switch file.mimeType {
        case "application/vnd.google-apps.document", "application/vnd.google-apps.presentation":
            raw = String(data: try await drive.exportFile(fileID: file.id, exportMimeType: "text/plain"), encoding: .utf8)
        case "application/vnd.google-apps.spreadsheet":
            raw = String(data: try await drive.exportFile(fileID: file.id, exportMimeType: "text/csv"), encoding: .utf8)
        case "application/pdf":
            raw = PDFDocument(data: try await drive.downloadContent(fileID: file.id))?.string
        case let mime where mime.hasPrefix("text/"):
            raw = String(data: try await drive.downloadContent(fileID: file.id), encoding: .utf8)
        default:
            return nil
        }
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text.count > Self.maxCharacters ? String(text.prefix(Self.maxCharacters)) + Self.truncationMark : text
    }
}

struct CalendarClient: CalendarFetchPort {
    static let root = "https://www.googleapis.com/calendar/v3"
    static let primary = "primary"
    static let upcomingLimit = "20"
    static let calendarListLimit = "250"
    static let secondsPerDay: TimeInterval = 86_400

    let requests: RequestClient
    let clock: @Sendable () -> Date

    init(requests: RequestClient, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.requests = requests
        self.clock = clock
    }

    func listCalendars() async throws -> [EventCalendar] {
        let url = try RequestClient.url(Self.root + "/users/me/calendarList", query: [
            URLQueryItem(name: "minAccessRole", value: "reader"),
            URLQueryItem(name: "showHidden", value: "false"),
            URLQueryItem(name: "maxResults", value: Self.calendarListLimit),
        ])
        return try CalendarParser.calendars(from: try await requests.send(url))
    }

    func upcomingEvents(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEvent] {
        let id = calendarID ?? Self.primary
        let now = clock()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var items = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: formatter.string(from: now)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: now.addingTimeInterval(TimeInterval(withinDays) * Self.secondsPerDay))),
            URLQueryItem(name: "maxResults", value: Self.upcomingLimit),
        ]
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id
        let url = try RequestClient.url(Self.root + "/calendars/\(encoded)/events", query: items)
        return try CalendarParser.events(from: try await requests.send(url), calendarID: id)
    }
}

struct ContactsClient: ContactsFetchPort {
    static let searchEndpoint = "https://people.googleapis.com/v1/people:searchContacts"
    static let readMask = "names,emailAddresses,phoneNumbers,organizations"
    static let listEndpoint = "https://people.googleapis.com/v1/people/me/connections"
    static let listMask = "names,emailAddresses"
    static let listPageSize = "1000"

    let requests: RequestClient
    let retryDelay: Duration

    init(requests: RequestClient, retryDelay: Duration = .milliseconds(500)) {
        self.requests = requests
        self.retryDelay = retryDelay
    }

    func searchContacts(query rawQuery: String?) async throws -> [Contact] {
        let query = Self.normalize(rawQuery)
        guard !query.isEmpty else { return [] }
        _ = try? await requests.send(Self.url(query: ""))
        var contacts = try await search(query)
        if contacts.isEmpty {
            try? await Task.sleep(for: retryDelay)
            contacts = try await search(query)
        }
        return contacts
    }

    func allContacts() async throws -> [Contact] {
        var contacts: [Contact] = []
        var token: String?
        repeat {
            let page = try ContactParser.page(from: try await requests.send(Self.listURL(token: token)))
            contacts += page.contacts
            token = page.next
        } while token != nil
        return contacts
    }

    private func search(_ query: String) async throws -> [Contact] {
        try ContactParser.contacts(from: try await requests.send(Self.url(query: query)))
    }

    static func url(query: String) throws -> URL {
        try RequestClient.url(searchEndpoint, query: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "readMask", value: readMask),
        ])
    }

    static func listURL(token: String?) throws -> URL {
        var query = [URLQueryItem(name: "personFields", value: listMask), URLQueryItem(name: "pageSize", value: listPageSize)]
        if let token { query.append(URLQueryItem(name: "pageToken", value: token)) }
        return try RequestClient.url(listEndpoint, query: query)
    }

    static func normalize(_ raw: String?) -> String {
        guard let raw else { return "" }
        return raw.replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .joined(separator: " ")
    }
}
