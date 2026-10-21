import Foundation

public struct FileFolder: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

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

public struct ProjectFolderRecord: Record, Equatable {
    public var id: String
    public var inlet: Inlet.ID
    public var folderID: String
    public var name: String

    public init(id: String, inlet: Inlet.ID, folderID: String, name: String) {
        self.id = id
        self.inlet = inlet
        self.folderID = folderID
        self.name = name
    }
}
