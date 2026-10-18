import Foundation

public enum OffersCollector {
    public static let maxDepthDefault = 3

    public struct FileWithParent: Sendable {
        public let file: GoogleDriveFile
        public let parentName: String?
        public init(file: GoogleDriveFile, parentName: String?) {
            self.file = file
            self.parentName = parentName
        }
    }

    public struct Result: Sendable {
        public let incoming: [ClassifiedOffer]
        public let outgoing: [ClassifiedOffer]
        public let incomingFolderFound: Bool
        public let outgoingFolderFound: Bool
        public init(incoming: [ClassifiedOffer], outgoing: [ClassifiedOffer],
                    incomingFolderFound: Bool, outgoingFolderFound: Bool) {
            self.incoming = incoming
            self.outgoing = outgoing
            self.incomingFolderFound = incomingFolderFound
            self.outgoingFolderFound = outgoingFolderFound
        }
    }

    public static func subfolder(in children: [GoogleDriveFile], matching keyword: String) -> GoogleDriveFile? {
        children.first {
            $0.mimeType == "application/vnd.google-apps.folder"
                && $0.name.lowercased().contains(keyword)
        }
    }

    private static let folderMime = "application/vnd.google-apps.folder"

    public static func findOfferFolders(
        rootFolderID: String, client: GoogleDriveFetching, maxDepth: Int = maxDepthDefault
    ) async throws -> (incoming: GoogleDriveFile?, outgoing: GoogleDriveFile?) {
        var incoming: GoogleDriveFile?
        var outgoing: GoogleDriveFile?
        var frontier: [(id: String, depth: Int)] = [(rootFolderID, 0)]

        while frontier.isEmpty == false {
            let (id, depth) = frontier.removeFirst()
            let children = try await client.listFolder(folderID: id)
            for child in children where child.mimeType == folderMime {
                let name = child.name.lowercased()
                if incoming == nil, name.contains("eingehende") { incoming = child }
                if outgoing == nil, name.contains("ausgehende") { outgoing = child }
            }
            if incoming != nil, outgoing != nil { break }
            if depth < maxDepth {
                for child in children where child.mimeType == folderMime
                    && child.id != incoming?.id && child.id != outgoing?.id {
                    frontier.append((child.id, depth + 1))
                }
            }
        }
        return (incoming, outgoing)
    }

    public static func collect(
        in folder: GoogleDriveFile?,
        client: GoogleDriveFetching,
        depth: Int,
        parentName: String? = nil,
        maxDepth: Int = maxDepthDefault
    ) async throws -> [FileWithParent] {
        guard let folder, depth < maxDepth else { return [] }
        let children = try await client.listFolder(folderID: folder.id)
        var result: [FileWithParent] = []
        var subfolderTasks: [Task<[FileWithParent], Error>] = []
        for child in children {
            if child.mimeType == "application/vnd.google-apps.folder" {
                let t = Task {
                    try await collect(in: child, client: client, depth: depth + 1,
                                      parentName: child.name, maxDepth: maxDepth)
                }
                subfolderTasks.append(t)
            } else {
                result.append(FileWithParent(file: child, parentName: parentName))
            }
        }
        for task in subfolderTasks {
            result.append(contentsOf: try await task.value)
        }
        return result
    }

    public static func load(
        rootFolderID: String,
        client: GoogleDriveFetching,
        maxDepth: Int = maxDepthDefault
    ) async throws -> Result {
        let (incomingFolder, outgoingFolder) = try await findOfferFolders(
            rootFolderID: rootFolderID, client: client, maxDepth: maxDepth)

        async let incomingFiles = collect(in: incomingFolder, client: client, depth: 0, maxDepth: maxDepth)
        async let outgoingFiles = collect(in: outgoingFolder, client: client, depth: 0, maxDepth: maxDepth)
        let (rawIncoming, rawOutgoing) = try await (incomingFiles, outgoingFiles)

        let cleanIncoming = rawIncoming.filter { DriveOfferWatcher.isAcceptedOfferFileType($0.file) }
        let cleanOutgoing = rawOutgoing.filter { DriveOfferWatcher.isAcceptedOfferFileType($0.file) }

        return Result(
            incoming: cleanIncoming.map {
                OfferDocumentClassifier.classify($0.file, isIncoming: true, folderName: $0.parentName)
            },
            outgoing: cleanOutgoing.map {
                OfferDocumentClassifier.classify($0.file, isIncoming: false, folderName: $0.parentName)
            },
            incomingFolderFound: incomingFolder != nil,
            outgoingFolderFound: outgoingFolder != nil
        )
    }
}
