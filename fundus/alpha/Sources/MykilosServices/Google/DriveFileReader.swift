import Foundation
import PDFKit

public enum DriveFileReader {
    private static let folderMime = "application/vnd.google-apps.folder"

    public static let maxChars = 400_000

    public static func findFile(named query: String, in rootFolderID: String,
                                client: GoogleDriveFetching, maxDepth: Int = 4) async throws -> GoogleDriveFile? {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else { return nil }
        var frontier: [(id: String, depth: Int)] = [(rootFolderID, 0)]
        while frontier.isEmpty == false {
            let (id, depth) = frontier.removeFirst()
            let children = try await client.listFolder(folderID: id)
            if let hit = children.first(where: { $0.mimeType != folderMime && $0.name.lowercased().contains(q) }) {
                return hit
            }
            if depth < maxDepth {
                for child in children where child.mimeType == folderMime {
                    frontier.append((child.id, depth + 1))
                }
            }
        }
        return nil
    }

    public static func text(of file: GoogleDriveFile, client: GoogleDriveFetching) async throws -> String? {
        let raw: String?
        switch file.mimeType {
        case "application/vnd.google-apps.document",
             "application/vnd.google-apps.presentation":
            raw = String(data: try await client.exportFile(fileID: file.id, exportMimeType: "text/plain"), encoding: .utf8)
        case "application/vnd.google-apps.spreadsheet":
            raw = String(data: try await client.exportFile(fileID: file.id, exportMimeType: "text/csv"), encoding: .utf8)
        case "application/pdf":
            let data = try await client.downloadContent(fileID: file.id)
            raw = PDFDocument(data: data)?.string
        case let m where m.hasPrefix("text/"):
            raw = String(data: try await client.downloadContent(fileID: file.id), encoding: .utf8)
        default:
            return nil
        }
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else { return nil }
        return text.count > maxChars ? String(text.prefix(maxChars)) + "\n… (gekürzt)" : text
    }
}
