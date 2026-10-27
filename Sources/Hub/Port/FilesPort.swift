import Foundation

public protocol FilesPort: Sendable {
    func projectFolders() async throws -> [FileFolder]
    func files(in folderID: String) async throws -> [FileEntry]
    func read(_ fileID: String) async throws -> Data
    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry
}
