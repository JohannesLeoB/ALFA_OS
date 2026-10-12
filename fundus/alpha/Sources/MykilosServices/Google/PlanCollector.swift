import Foundation

public enum PlanCategory: String, CaseIterable, Sendable, Identifiable, Hashable {
    case plaene, werkszeichnung, renderings, vorplanung, layouts, praesentation

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .plaene:         "Pläne"
        case .werkszeichnung: "Werkszeichnung"
        case .renderings:     "Renderings"
        case .vorplanung:     "Vorplanung & Screenshots"
        case .layouts:        "Layouts"
        case .praesentation:  "Präsentation"
        }
    }

    public var iconName: String {
        switch self {
        case .plaene:         "map"
        case .werkszeichnung: "pencil.and.ruler"
        case .renderings:     "photo.on.rectangle"
        case .vorplanung:     "camera.viewfinder"
        case .layouts:        "square.grid.2x2"
        case .praesentation:  "rectangle.on.rectangle.angled"
        }
    }

    public var inGlobalKatalog: Bool { self != .praesentation }

    var keywords: [String] {
        switch self {
        case .plaene:         ["plane", "plaene"]
        case .werkszeichnung: ["werkszeichnung", "werkzeichnung"]
        case .renderings:     ["rendering"]
        case .vorplanung:     ["vorplanung", "screenshot"]
        case .layouts:        ["layout"]
        case .praesentation:  ["prasentation", "praesentation", "presentation"]
        }
    }

    static let matchOrder: [PlanCategory] = [
        .werkszeichnung, .vorplanung, .renderings, .layouts, .praesentation, .plaene
    ]
}

public enum PlanCollector {
    public static let maxDepthDefault = OffersCollector.maxDepthDefault

    public struct Result: Sendable {
        public let filesByCategory: [PlanCategory: [GoogleDriveFile]]
        public let foundCategories: Set<PlanCategory>
        public init(filesByCategory: [PlanCategory: [GoogleDriveFile]],
                    foundCategories: Set<PlanCategory>) {
            self.filesByCategory = filesByCategory
            self.foundCategories = foundCategories
        }

        public var totalFileCount: Int { filesByCategory.values.reduce(0) { $0 + $1.count } }
        public var isEmpty: Bool { totalFileCount == 0 }
    }

    private static let folderMime = "application/vnd.google-apps.folder"

    static func foldedName(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "de_DE"))
    }

    static func category(forFolderName name: String) -> PlanCategory? {
        let folded = foldedName(name)
        for candidate in PlanCategory.matchOrder
        where candidate.keywords.contains(where: { folded.contains($0) }) {
            return candidate
        }
        return nil
    }

    nonisolated public static let acceptedPlanExtensions: Set<String> = [
        "pdf",
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "webp"
    ]

    nonisolated public static func isAcceptedPlanFileType(_ file: GoogleDriveFile) -> Bool {
        if file.isFolder { return false }
        let ext = (file.name as NSString).pathExtension.lowercased()
        if ext.isEmpty {
            return file.mimeType == "application/pdf" || file.mimeType.hasPrefix("image/")
        }
        return acceptedPlanExtensions.contains(ext)
    }

    public static func findPlanFolders(
        rootFolderID: String, client: GoogleDriveFetching, maxDepth: Int = maxDepthDefault
    ) async throws -> [PlanCategory: GoogleDriveFile] {
        var found: [PlanCategory: GoogleDriveFile] = [:]
        var frontier: [(id: String, depth: Int)] = [(rootFolderID, 0)]

        while frontier.isEmpty == false {
            let (id, depth) = frontier.removeFirst()
            let children = try await client.listFolder(folderID: id)
            var categorizedIDs: Set<String> = []
            for child in children where child.mimeType == folderMime {
                if let category = category(forFolderName: child.name) {
                    categorizedIDs.insert(child.id)
                    if found[category] == nil { found[category] = child }
                }
            }
            if found.count == PlanCategory.allCases.count { break }
            if depth < maxDepth {
                for child in children where child.mimeType == folderMime
                    && categorizedIDs.contains(child.id) == false {
                    frontier.append((child.id, depth + 1))
                }
            }
        }
        return found
    }

    public static func load(
        rootFolderID: String,
        client: GoogleDriveFetching,
        maxDepth: Int = maxDepthDefault
    ) async throws -> Result {
        let folders = try await findPlanFolders(
            rootFolderID: rootFolderID, client: client, maxDepth: maxDepth)

        var filesByCategory: [PlanCategory: [GoogleDriveFile]] = [:]
        try await withThrowingTaskGroup(of: (PlanCategory, [GoogleDriveFile]).self) { group in
            for (category, folder) in folders {
                group.addTask {
                    let collected = try await OffersCollector.collect(
                        in: folder, client: client, depth: 0, maxDepth: maxDepth)
                    let files = collected.map(\.file)
                        .filter { isAcceptedPlanFileType($0) }
                        .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
                    return (category, files)
                }
            }
            for try await (category, files) in group {
                filesByCategory[category] = files
            }
        }

        return Result(filesByCategory: filesByCategory,
                      foundCategories: Set(folders.keys))
    }
}
