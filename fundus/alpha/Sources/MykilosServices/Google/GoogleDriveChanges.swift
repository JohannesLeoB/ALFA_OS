import Foundation

public struct GoogleDriveChange: Sendable, Equatable {
    public let file: GoogleDriveFile?
    public let parentIDs: [String]
    public let removed: Bool

    public init(file: GoogleDriveFile?, parentIDs: [String], removed: Bool) {
        self.file = file; self.parentIDs = parentIDs; self.removed = removed
    }
}

public protocol GoogleDriveChangesReading: Sendable {
    func driveID(forFolder folderID: String) async throws -> String?
    func startPageToken(driveID: String?) async throws -> String
    func changes(since pageToken: String, driveID: String?) async throws
        -> (changes: [GoogleDriveChange], nextPageToken: String)
}

extension GoogleDriveClient: GoogleDriveChangesReading {
    static let changesBaseURL = "https://www.googleapis.com/drive/v3/changes"
    static let filesBaseURL = "https://www.googleapis.com/drive/v3/files"

    public func driveID(forFolder folderID: String) async throws -> String? {
        let token = try await accessToken()
        var parts = URLComponents(string: "\(Self.filesBaseURL)/\(folderID)")
        parts?.queryItems = [URLQueryItem(name: "fields", value: "driveId"),
                             URLQueryItem(name: "supportsAllDrives", value: "true")]
        guard let url = parts?.url else { throw GoogleDriveError.invalidResponse }
        struct Response: Decodable { let driveId: String? }
        return (try? JSONDecoder().decode(Response.self, from: try await get(url, token: token)))?.driveId
    }

    public func startPageToken(driveID: String?) async throws -> String {
        let token = try await accessToken()
        guard let url = Self.startPageTokenURL(driveID: driveID, baseURL: Self.changesBaseURL) else {
            throw GoogleDriveError.invalidResponse
        }
        struct Response: Decodable { let startPageToken: String }
        guard let start = try? JSONDecoder().decode(
            Response.self, from: try await get(url, token: token)).startPageToken
        else { throw GoogleDriveError.decodingFailed }
        return start
    }

    public func changes(since pageToken: String, driveID: String?) async throws
        -> (changes: [GoogleDriveChange], nextPageToken: String) {
        let token = try await accessToken()
        var collected: [GoogleDriveChange] = []
        var page: String? = pageToken
        var newToken = pageToken

        for _ in 0..<20 {
            guard let current = page,
                  let url = Self.changesURL(pageToken: current, driveID: driveID,
                                            baseURL: Self.changesBaseURL) else { break }
            let parsed = try Self.parseChanges(try await get(url, token: token))
            collected += parsed.changes
            if let next = parsed.nextPageToken {
                page = next
            } else {
                newToken = parsed.newStartPageToken ?? current
                break
            }
        }
        return (collected, newToken)
    }

    static func startPageTokenURL(driveID: String?, baseURL: String) -> URL? {
        var parts = URLComponents(string: "\(baseURL)/startPageToken")
        var items = [URLQueryItem(name: "supportsAllDrives", value: "true")]
        if let driveID { items.append(URLQueryItem(name: "driveId", value: driveID)) }
        parts?.queryItems = items
        return parts?.url
    }

    static func changesURL(pageToken: String, driveID: String?, baseURL: String) -> URL? {
        var parts = URLComponents(string: baseURL)
        var items = [
            URLQueryItem(name: "pageToken", value: pageToken),
            URLQueryItem(name: "pageSize", value: "200"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "includeItemsFromAllDrives", value: "true"),
            URLQueryItem(name: "fields", value: "newStartPageToken,nextPageToken,"
                         + "changes(removed,fileId,file(id,name,mimeType,modifiedTime,webViewLink,parents,trashed))")
        ]
        if let driveID { items.append(URLQueryItem(name: "driveId", value: driveID)) }
        parts?.queryItems = items
        return parts?.url
    }

    static func parseChanges(_ data: Data) throws
        -> (changes: [GoogleDriveChange], nextPageToken: String?, newStartPageToken: String?) {
        struct Entry: Decodable {
            struct File: Decodable {
                let id: String; let name: String; let mimeType: String
                let modifiedTime: String?; let webViewLink: String?
                let parents: [String]?; let trashed: Bool?
            }
            let removed: Bool?
            let file: File?
        }
        struct Response: Decodable {
            let changes: [Entry]
            let nextPageToken: String?
            let newStartPageToken: String?
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw GoogleDriveError.decodingFailed
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let changes = response.changes.map { entry -> GoogleDriveChange in
            let file = entry.file.map {
                GoogleDriveFile(id: $0.id, name: $0.name, mimeType: $0.mimeType,
                                modifiedAt: $0.modifiedTime.flatMap(iso.date(from:)),
                                webViewLink: $0.webViewLink)
            }
            return GoogleDriveChange(file: file, parentIDs: entry.file?.parents ?? [],
                                     removed: (entry.removed ?? false) || (entry.file?.trashed ?? false))
        }
        return (changes, response.nextPageToken, response.newStartPageToken)
    }
}
