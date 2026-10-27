import Foundation

public struct MessageBody: Equatable, Sendable {
    public var text: String?
    public var html: String?
    public var inlineImages: [String: String]
    public var attachments: [AttachmentInfo]

    public init(text: String? = nil, html: String? = nil, inlineImages: [String: String] = [:],
                attachments: [AttachmentInfo] = []) {
        self.text = text
        self.html = html
        self.inlineImages = inlineImages
        self.attachments = attachments
    }
}

public enum MessageContent: Equatable, Sendable {
    case bodyLoading
    case text(String)
    case html(String, inlineImages: [String: String])
}

public struct MessageDocument: Equatable, Sendable {
    public let name: String
    public let data: Data
}

public struct AttachmentInfo: Equatable, Sendable, Codable {
    var id: String
    var filename: String
    var mimeType: String
    var sizeBytes: Int

    public init(id: String, filename: String, mimeType: String, sizeBytes: Int) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
    }
}

public struct AttachmentEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let size: String
}

struct OutgoingMessage: Equatable, Sendable {
    var data: Data
    var sender: String
    var recipients: [String]
}
