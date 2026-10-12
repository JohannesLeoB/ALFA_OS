import Foundation
import MykilosKit

public enum DriveOrdnerbaumBuilder {
    public struct Result: Sendable {
        public let rootOrdnerID: String
        public let unterordnerIDs: [String: String]
    }

    public static func baue(
        drive: any DriveFolderProvisioning,
        parentID: String,
        folderName: String,
        schema: FolderSchema,
        bestehendeUnterordnerIDs: [String: String] = [:],
        bekannteRootOrdnerID: String? = nil
    ) async throws -> Result {
        let rootOrdnerID: String
        if let bekannteRootOrdnerID {
            rootOrdnerID = bekannteRootOrdnerID
        } else {
            rootOrdnerID = try await drive.findOrCreateSubfolder(parentID: parentID, name: folderName)
        }

        var erzeugteIDs = bestehendeUnterordnerIDs
        for pfad in schema.allePfade() {
            var parent = rootOrdnerID
            var teilpfad = ""
            for komponente in pfad.split(separator: "/").map(String.init) {
                teilpfad = teilpfad.isEmpty ? komponente : teilpfad + "/" + komponente
                if let cached = erzeugteIDs[teilpfad] {
                    parent = cached
                } else {
                    let id = try await drive.findOrCreateSubfolder(parentID: parent, name: komponente)
                    erzeugteIDs[teilpfad] = id
                    parent = id
                }
            }
        }
        return Result(rootOrdnerID: rootOrdnerID, unterordnerIDs: erzeugteIDs)
    }
}
