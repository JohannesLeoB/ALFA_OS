import Foundation

public struct DriveFolderSuggestion: Equatable, Sendable {
    public let folderID: String

    public let folderName: String

    public let reason: String

    public init(folderID: String, folderName: String, reason: String) {
        self.folderID = folderID
        self.folderName = folderName
        self.reason = reason
    }
}

public enum DriveFolderSuggestionError: Error, Sendable, Equatable {
    case noDriveFolderConfigured

    case uploadDestinationForbidden(String)
}

public struct DriveFolderSuggestionResolver: Sendable {
    private let driveClient: GoogleDriveFetching

    public static let forbiddenFolderIDs: Set<String> = [
        "0AOeReQBQKkKBUk9PVA"
    ]

    public init(driveClient: GoogleDriveFetching) {
        self.driveClient = driveClient
    }

    public func suggest(
        projectDriveFolderID: String?,
        preferredSubfolderKeyword: String? = nil
    ) async throws -> DriveFolderSuggestion {
        guard let rootID = projectDriveFolderID, !rootID.isEmpty else {
            throw DriveFolderSuggestionError.noDriveFolderConfigured
        }

        try Self.assertNotForbidden(rootID)

        if let keyword = preferredSubfolderKeyword, !keyword.isEmpty {
            if let sub = try await findSubfolder(in: rootID, keyword: keyword) {
                return sub
            }
        }

        let name: String
        do {
            name = try await driveClient.getFileName(folderID: rootID)
        } catch {
            name = rootID
        }
        return DriveFolderSuggestion(
            folderID: rootID,
            folderName: name,
            reason: "Projekt-Ordner"
        )
    }

    static func assertNotForbidden(_ folderID: String) throws {
        if forbiddenFolderIDs.contains(folderID) {
            throw DriveFolderSuggestionError.uploadDestinationForbidden(folderID)
        }
    }

    private func findSubfolder(in parentID: String, keyword: String) async throws -> DriveFolderSuggestion? {
        let entries = try await driveClient.listFolder(folderID: parentID)
        guard let match = entries.first(where: {
            $0.isFolder && $0.name.localizedCaseInsensitiveContains(keyword)
        }) else {
            return nil
        }

        guard !Self.forbiddenFolderIDs.contains(match.id) else {
            return nil
        }
        return DriveFolderSuggestion(
            folderID: match.id,
            folderName: match.name,
            reason: "Unterordner fuer \"\(keyword)\""
        )
    }
}
