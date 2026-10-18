import Foundation

public struct DriveFileRef: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var mimeType: String
    public var webViewLink: String?
    public var subtitle: String?

    public init(id: String, name: String, mimeType: String, webViewLink: String? = nil, subtitle: String? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.webViewLink = webViewLink
        self.subtitle = subtitle
    }
}
