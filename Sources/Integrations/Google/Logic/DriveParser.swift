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
