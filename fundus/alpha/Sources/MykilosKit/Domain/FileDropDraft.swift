import Foundation

public struct DroppedFile: Sendable, Equatable, Identifiable {
    public var id: String { "\(fileName)-\(data.count)" }

    public let fileName: String

    public let mimeType: String

    public let data: Data

    public init(fileName: String, mimeType: String, data: Data) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }

    public var humanSize: String {
        let bytes = data.count
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    public var iconName: String {
        if mimeType == "application/pdf" { return "doc.richtext" }
        if mimeType.hasPrefix("image/") { return "photo" }
        if mimeType.hasPrefix("text/") { return "doc.text" }
        return "doc"
    }
}

public struct DriveFolderChoice: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum DriveUploadOutcome: Sendable, Equatable {
    case uploaded(webLink: String?)

    case failed(String)

    case permissionRequired
}
