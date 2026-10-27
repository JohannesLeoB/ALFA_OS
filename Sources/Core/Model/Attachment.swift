import Foundation

public struct Attachment: Codable, Sendable, Equatable, Identifiable {
    public var filename: String
    public var mimeType: String
    public var data: Data

    public var id: String { "\(filename)-\(data.count)" }

    public init(filename: String, mimeType: String, data: Data) {
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
    }

    public var humanSize: String {
        let bytes = data.count
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}
