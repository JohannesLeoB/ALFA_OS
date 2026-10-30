import Foundation

struct DriveClient: DrivePort {
    static let filesEndpoint = "https://www.googleapis.com/drive/v3/files"
    static let uploadEndpoint = "https://www.googleapis.com/upload/drive/v3/files"
    static let drivesEndpoint = "https://www.googleapis.com/drive/v3/drives"
    static let listFields = "nextPageToken,files(id,name,mimeType,modifiedTime,webViewLink)"
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
