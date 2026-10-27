import Foundation
import PDFKit

struct DriveTextClient: Sendable {
    static let maxCharacters = 400_000
    static let maxDepth = 4
    static let truncationMark = "\n\u{2026}"

    let drive: any DrivePort

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
