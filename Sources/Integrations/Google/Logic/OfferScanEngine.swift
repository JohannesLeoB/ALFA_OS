import Foundation

enum OfferScanEngine {
    static let defaultDepth = 3

    private struct Located: Sendable {
        let file: DriveFile
        let parentName: String?
    }

    static func load(rootFolderID: String, drive: any DrivePort, convention: OfferConvention,
                     maxDepth: Int = defaultDepth) async throws -> OfferScanResult {
        let (incomingFolder, outgoingFolder) = try await findFolders(
            rootFolderID: rootFolderID, drive: drive, convention: convention, maxDepth: maxDepth)
        async let incoming = collect(in: incomingFolder, drive: drive, depth: 0, parentName: nil, maxDepth: maxDepth)
        async let outgoing = collect(in: outgoingFolder, drive: drive, depth: 0, parentName: nil, maxDepth: maxDepth)
        let (rawIncoming, rawOutgoing) = try await (incoming, outgoing)
        return OfferScanResult(
            incoming: classify(rawIncoming, isIncoming: true, convention: convention),
            outgoing: classify(rawOutgoing, isIncoming: false, convention: convention))
    }

    static func findFolders(rootFolderID: String, drive: any DrivePort, convention: OfferConvention,
                            maxDepth: Int) async throws -> (incoming: DriveFile?, outgoing: DriveFile?) {
        var incoming: DriveFile?
        var outgoing: DriveFile?
        var frontier: [(id: String, depth: Int)] = [(rootFolderID, 0)]
        while !frontier.isEmpty {
            let (id, depth) = frontier.removeFirst()
            let children = try await drive.listFolder(folderID: id)
            for child in children where child.isFolder {
                let name = child.name.lowercased()
                if incoming == nil, name.contains(convention.incomingFolderKeyword.lowercased()) { incoming = child }
                if outgoing == nil, name.contains(convention.outgoingFolderKeyword.lowercased()) { outgoing = child }
            }
            if incoming != nil, outgoing != nil { break }
            if depth < maxDepth {
                for child in children where child.isFolder && child.id != incoming?.id && child.id != outgoing?.id {
                    frontier.append((child.id, depth + 1))
                }
            }
        }
        return (incoming, outgoing)
    }

    private static func collect(in folder: DriveFile?, drive: any DrivePort, depth: Int, parentName: String?,
                                maxDepth: Int) async throws -> [Located] {
        guard let folder, depth < maxDepth else { return [] }
        let children = try await drive.listFolder(folderID: folder.id)
        let own = children.filter { !$0.isFolder }.map { Located(file: $0, parentName: parentName) }
        let nested = try await withThrowingTaskGroup(of: (Int, [Located]).self) { group in
            for (index, child) in children.enumerated() where child.isFolder {
                group.addTask {
                    (index, try await collect(in: child, drive: drive, depth: depth + 1, parentName: child.name,
                                              maxDepth: maxDepth))
                }
            }
            var parts: [(Int, [Located])] = []
            for try await part in group { parts.append(part) }
            return parts.sorted { $0.0 < $1.0 }.flatMap(\.1)
        }
        return own + nested
    }

    private static func classify(_ located: [Located], isIncoming: Bool, convention: OfferConvention) -> [ClassifiedOffer] {
        located.filter { OfferEngine.isAcceptedFileType($0.file) }.map {
            OfferClassificationEngine.classify($0.file, isIncoming: isIncoming, folderName: $0.parentName,
                                               convention: convention)
        }
    }
}

struct OfferScanResult: Equatable, Sendable {
    var incoming: [ClassifiedOffer]
    var outgoing: [ClassifiedOffer]
}

enum OfferEngine {
    static let acceptedExtensions: Set<String> = [
        "pdf", "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "webp", "eml", "msg",
    ]
    static let acceptedMimeTypes: Set<String> = ["application/pdf", "message/rfc822"]

    static func isAcceptedFileType(_ file: DriveFile) -> Bool {
        if file.isFolder { return false }
        let ext = (file.name as NSString).pathExtension.lowercased()
        if ext.isEmpty {
            return acceptedMimeTypes.contains(file.mimeType) || file.mimeType.hasPrefix("image/")
        }
        return acceptedExtensions.contains(ext)
    }
}
