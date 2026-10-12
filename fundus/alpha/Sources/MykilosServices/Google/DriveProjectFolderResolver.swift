import Foundation

public struct DriveProjectFolderResolver: Sendable {
    private let client: any GoogleDriveFetching

    public init(client: any GoogleDriveFetching = GoogleDriveClient()) {
        self.client = client
    }

    public func resolveFragebogenOrdner(projektDriveOrdnerID: String) async throws -> String {
        let infosID = try await client.findOrCreateSubfolder(
            parentID: projektDriveOrdnerID,
            name: "01 INFOS"
        )
        let fragebogenID = try await client.findOrCreateSubfolder(
            parentID: infosID,
            name: "07 Fragebogen"
        )
        return fragebogenID
    }
}
