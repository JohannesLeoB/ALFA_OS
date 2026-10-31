import Foundation

struct GmailMessage: Identifiable, Equatable, Sendable {
    var id: String
    var threadID: String = ""
    var subject: String
    var from: String
    var fromRaw: String = ""
    var toRaw: String = ""
    var ccRaw: String = ""
    var bccRaw: String = ""
    var replyToRaw: String = ""
    var snippet: String = ""
    var receivedAt: Date?
    var labels: [String] = []
    var attachments: [GmailAttachment] = []
    var messageIDHeader: String = ""
    var likelyAttachments = false
}

struct GmailAttachment: Equatable, Sendable {
    var attachmentID: String
    var filename: String
    var mimeType: String
    var sizeBytes: Int
}

struct GmailMailBody: Equatable, Sendable {
    var text: String?
    var html: String?
    var inlineImages: [String: String] = [:]
    var attachments: [GmailAttachment] = []
}

struct GmailIDs: Equatable, Sendable {
    var ids: [String]
    var nextPageToken: String?
    var estimate: Int?
}

struct GmailChanges: Equatable, Sendable {
    var ids: Set<String>
    var historyID: String
}

struct GmailPage: Equatable, Sendable {
    var messages: [GmailMessage]
    var nextPageToken: String?
}
