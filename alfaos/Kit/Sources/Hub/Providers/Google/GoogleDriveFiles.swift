import Foundation
import AlfaServices

struct GoogleDriveFiles: FilesPort {
    let client: GoogleDriveClient
    let tokens: any GoogleAccessTokenProviding
    let session: URLSession
    let root: String?

    func projectFolders() async throws -> [FileFolder] {
        guard let root else { throw GoogleProviderError.projectRootMissing }
        return try await client.listFolder(folderID: root).filter(\.isFolder).map { FileFolder(id: $0.id, name: $0.name) }
    }

    func files(in folderID: String) async throws -> [FileEntry] {
        try await client.listFolder(folderID: folderID)
            .filter { $0.isFolder || !$0.mimeType.hasPrefix(Self.nativePrefix) }
            .map { FileEntry(id: $0.id, name: $0.name, mimeType: $0.mimeType, isFolder: $0.isFolder) }
    }

    func read(_ fileID: String) async throws -> Data {
        try await client.downloadContent(fileID: fileID)
    }

    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry {
        let token: String
        do {
            token = try await tokens.validAccessToken()
        } catch {
            throw GoogleDriveError.notConnected
        }
        var components = URLComponents(string: "https://www.googleapis.com/upload/drive/v3/files")
        components?.queryItems = [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "fields", value: "id,name,mimeType"),
            URLQueryItem(name: "supportsAllDrives", value: "true")
        ]
        guard let url = components?.url,
              let meta = try? JSONSerialization.data(withJSONObject: ["name": name, "parents": [folderID]]) else {
            throw GoogleDriveError.invalidResponse
        }
        let boundary = "part_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
        body.append(meta)
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (answer, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleDriveError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleDriveError.httpError(http.statusCode) }
        struct Made: Decodable {
            let id: String
            let name: String
            let mimeType: String
        }
        guard let made = try? JSONDecoder().decode(Made.self, from: answer) else { throw GoogleDriveError.decodingFailed }
        return FileEntry(id: made.id, name: made.name, mimeType: made.mimeType)
    }

    static let nativePrefix = "application/vnd.google-apps."
}
