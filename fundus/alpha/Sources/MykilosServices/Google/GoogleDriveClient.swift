import Foundation

public struct GoogleDriveFile: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var name: String
    public var mimeType: String
    public var modifiedAt: Date?
    public var webViewLink: String?

    public var fileSize: Int64?

    public var thumbnailLink: String?

    public init(id: String, name: String, mimeType: String, modifiedAt: Date?, webViewLink: String?, fileSize: Int64? = nil, thumbnailLink: String? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.modifiedAt = modifiedAt
        self.webViewLink = webViewLink
        self.fileSize = fileSize
        self.thumbnailLink = thumbnailLink
    }

    public var isFolder: Bool { mimeType == "application/vnd.google-apps.folder" }

    public var iconName: String {
        switch mimeType {
        case "application/vnd.google-apps.folder": "folder"
        case "application/pdf": "doc.richtext"
        case "application/vnd.google-apps.spreadsheet": "tablecells"
        case "application/vnd.google-apps.document": "doc.text"
        case "application/vnd.google-apps.presentation": "rectangle.on.rectangle"
        default:
            mimeType.hasPrefix("image/") ? "photo" : "doc"
        }
    }

    public var typeLabel: String {
        switch mimeType {
        case "application/vnd.google-apps.folder":       "Ordner"
        case "application/pdf":                          "PDF-Dokument"
        case "application/vnd.google-apps.spreadsheet":  "Google Sheets"
        case "application/vnd.google-apps.document":     "Google Doc"
        case "application/vnd.google-apps.presentation": "Google Slides"
        default:
            mimeType.hasPrefix("image/") ? "Bild"
            : mimeType.components(separatedBy: "/").last?.uppercased() ?? "Datei"
        }
    }

    public var fileSizeLabel: String {
        guard let bytes = fileSize else { return "—" }
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.0f KB", kb < 1 ? 1 : kb)
        }
        return String(format: "%.1f MB", kb / 1024)
    }
}

public enum GoogleDriveError: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed

    case uploadDestinationForbidden(String)
}

public protocol GoogleDriveFetching: Sendable {
    func listFolder(folderID: String) async throws -> [GoogleDriveFile]
    func getFileName(folderID: String) async throws -> String

    func downloadContent(fileID: String) async throws -> Data

    func exportFile(fileID: String, exportMimeType: String) async throws -> Data

    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String
}

public extension GoogleDriveFetching {
    func exportFile(fileID: String, exportMimeType: String) async throws -> Data {
        throw GoogleDriveError.invalidResponse
    }

    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String {
        throw GoogleDriveError.invalidResponse
    }
}

public struct GoogleDriveClient: GoogleDriveFetching {
    private let tokenProvider: GoogleAccessTokenProviding
    private let session: URLSession
    private let baseURL = "https://www.googleapis.com/drive/v3/files"

    public init(
        tokenProvider: GoogleAccessTokenProviding = GoogleAccessTokenProvider(),
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
    }

    func accessToken() async throws -> String {
        guard let token = try? await tokenProvider.validAccessToken() else {
            throw GoogleDriveError.notConnected
        }
        return token
    }

    func get(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleDriveError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw GoogleDriveError.httpError(http.statusCode)
        }
        return data
    }

    public func listFolder(folderID: String) async throws -> [GoogleDriveFile] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleDriveError.notConnected
        }
        var allFiles: [GoogleDriveFile] = []
        var pageToken: String?

        for _ in 0..<20 {
            guard let url = Self.buildListFolderURL(folderID: folderID, pageToken: pageToken, baseURL: baseURL) else {
                throw GoogleDriveError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GoogleDriveError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { throw GoogleDriveError.httpError(http.statusCode) }
            let page = try Self.parseFilesPage(from: data)
            allFiles.append(contentsOf: page.files)
            guard let next = page.nextPageToken else { break }
            pageToken = next
        }
        return allFiles
    }

    public func downloadContent(fileID: String) async throws -> Data {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleDriveError.notConnected
        }
        guard let url = URL(string: "\(baseURL)/\(fileID)?alt=media&supportsAllDrives=true") else {
            throw GoogleDriveError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw GoogleDriveError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    public func exportFile(fileID: String, exportMimeType: String) async throws -> Data {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleDriveError.notConnected
        }
        var comps = URLComponents(string: "\(baseURL)/\(fileID)/export")
        comps?.queryItems = [URLQueryItem(name: "mimeType", value: exportMimeType)]
        guard let url = comps?.url else { throw GoogleDriveError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw GoogleDriveError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    public func getFileName(folderID: String) async throws -> String {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleDriveError.notConnected
        }
        guard let url = URL(string: "\(baseURL)/\(folderID)?fields=name&supportsAllDrives=true") else {
            throw GoogleDriveError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else { throw GoogleDriveError.invalidResponse }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = obj["name"] as? String else { throw GoogleDriveError.decodingFailed }
        return name
    }

    static func buildListFolderURL(folderID: String, pageToken: String? = nil, baseURL: String) -> URL? {
        var components = URLComponents(string: baseURL)
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: "'\(folderID)' in parents and trashed=false"),
            URLQueryItem(name: "fields", value: "nextPageToken,files(id,name,mimeType,modifiedTime,webViewLink,size,thumbnailLink)"),
            URLQueryItem(name: "pageSize", value: "100"),
            URLQueryItem(name: "orderBy", value: "folder,name"),

            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
        ]
        if let token = pageToken {
            items.append(URLQueryItem(name: "pageToken", value: token))
        }
        components?.queryItems = items
        return components?.url
    }

    static func parseFilesPage(from data: Data) throws -> (files: [GoogleDriveFile], nextPageToken: String?) {
        do {
            let decoded = try JSONDecoder().decode(GoogleDriveListResponse.self, from: data)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let files = decoded.files.map { entry in
                GoogleDriveFile(
                    id: entry.id,
                    name: entry.name,
                    mimeType: entry.mimeType,
                    modifiedAt: entry.modifiedTime.flatMap { isoFormatter.date(from: $0) },
                    webViewLink: entry.webViewLink,
                    fileSize: entry.size.flatMap { Int64($0) },
                    thumbnailLink: entry.thumbnailLink
                )
            }
            return (files, decoded.nextPageToken)
        } catch {
            throw GoogleDriveError.decodingFailed
        }
    }

    static func parseFiles(from data: Data) throws -> [GoogleDriveFile] {
        try parseFilesPage(from: data).files
    }

    static let forbiddenParentFolderIDs: Set<String> = [
        "0AOeReQBQKkKBUk9PVA"
    ]

    public func uploadFile(
        name: String,
        mimeType: String,
        data: Data,
        parentFolderID: String,
        tags: [String] = []
    ) async throws -> GoogleDriveFile {
        guard !Self.forbiddenParentFolderIDs.contains(parentFolderID) else {
            throw GoogleDriveError.uploadDestinationForbidden(parentFolderID)
        }
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleDriveError.notConnected
        }
        guard let url = Self.buildUploadURL(baseURL: baseURL) else {
            throw GoogleDriveError.invalidResponse
        }
        let boundary = "mykilos_boundary_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var metadata: [String: Any] = ["name": name, "parents": [parentFolderID]]
        if tags.isEmpty == false {
            metadata["properties"] = ["mykilos_tags": tags.joined(separator: ",")]
        }
        let body = Self.buildMultipartBody(
            boundary: boundary,
            metadata: metadata,
            mimeType: mimeType,
            data: data
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw GoogleDriveError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try Self.parseUploadedFile(from: responseData)
    }

    static func buildUploadURL(baseURL: String) -> URL? {
        var components = URLComponents(string: "https://www.googleapis.com/upload/drive/v3/files")
        components?.queryItems = [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "fields", value: "id,name,mimeType,webViewLink"),
            URLQueryItem(name: "supportsAllDrives", value: "true")
        ]
        return components?.url
    }

    static func buildMultipartBody(
        boundary: String,
        metadata: [String: Any],
        mimeType: String,
        data: Data
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"
        let dash = "--"

        body.append(contentsOf: "\(dash)\(boundary)\(crlf)".utf8)
        body.append(contentsOf: "Content-Type: application/json; charset=UTF-8\(crlf)\(crlf)".utf8)
        if let json = try? JSONSerialization.data(withJSONObject: metadata) {
            body.append(json)
        }
        body.append(contentsOf: crlf.utf8)

        body.append(contentsOf: "\(dash)\(boundary)\(crlf)".utf8)
        body.append(contentsOf: "Content-Type: \(mimeType)\(crlf)\(crlf)".utf8)
        body.append(data)
        body.append(contentsOf: crlf.utf8)

        body.append(contentsOf: "\(dash)\(boundary)\(dash)\(crlf)".utf8)
        return body
    }

    public func findOrCreateSubfolder(parentID: String, name: String) async throws -> String {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleDriveError.notConnected
        }

        if let existingID = try? await searchSubfolder(
            parentID: parentID, name: name, accessToken: accessToken
        ) {
            return existingID
        }

        return try await createSubfolder(parentID: parentID, name: name, accessToken: accessToken)
    }

    private func searchSubfolder(parentID: String, name: String, accessToken: String) async throws -> String? {
        guard let url = Self.buildFindSubfolderURL(parentID: parentID, name: name, baseURL: baseURL) else {
            throw GoogleDriveError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw GoogleDriveError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = obj["files"] as? [[String: Any]],
              let first = files.first,
              let id = first["id"] as? String else {
            return nil
        }
        return id
    }

    private func createSubfolder(parentID: String, name: String, accessToken: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)?fields=id&supportsAllDrives=true") else {
            throw GoogleDriveError.invalidResponse
        }
        let metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": [parentID]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: metadata) else {
            throw GoogleDriveError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw GoogleDriveError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["id"] as? String else {
            throw GoogleDriveError.decodingFailed
        }
        return id
    }

    static func buildFindSubfolderURL(parentID: String, name: String, baseURL: String) -> URL? {
        let safeParent = parentID.replacingOccurrences(of: "'", with: "\\'")
        let safeName   = name.replacingOccurrences(of: "'", with: "\\'")
        let query = "'\(safeParent)' in parents and name='\(safeName)' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "files(id,name)"),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
        ]
        return components?.url
    }

    static func parseUploadedFile(from data: Data) throws -> GoogleDriveFile {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["id"] as? String,
              let name = obj["name"] as? String,
              let mime = obj["mimeType"] as? String else {
            throw GoogleDriveError.decodingFailed
        }
        return GoogleDriveFile(
            id: id,
            name: name,
            mimeType: mime,
            modifiedAt: nil,
            webViewLink: obj["webViewLink"] as? String
        )
    }
}

private struct GoogleDriveListResponse: Decodable {
    var files: [GoogleDriveFileEntry]
    var nextPageToken: String?
}

private struct GoogleDriveFileEntry: Decodable {
    var id: String
    var name: String
    var mimeType: String
    var modifiedTime: String?
    var webViewLink: String?
    var size: String?
    var thumbnailLink: String?
}
