public struct FileEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let mimeType: String
    public let isFolder: Bool

    public init(id: String, name: String, mimeType: String, isFolder: Bool = false) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.isFolder = isFolder
    }
}

public struct FileFolder: Identifiable, Hashable, Sendable {
    public static let ownDrive = "root"

    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct ProjectFolder: Item, Equatable {
    public var id: String
    public var inlet: Inlet.ID
    public var folder: FileFolder

    init(inlet: Inlet.ID, folder: FileFolder) {
        self.id = inlet + "/" + folder.id
        self.inlet = inlet
        self.folder = folder
    }
}
