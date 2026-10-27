import Foundation

struct GmailMessage: Identifiable, Equatable, Sendable {
    var id: String
    var threadID: String = ""
    var subject: String
    var from: String
    var fromRaw: String = ""
    var toRaw: String = ""
    var ccRaw: String = ""
    var snippet: String = ""
    var receivedAt: Date?
    var labels: [String] = []
    var attachments: [GmailAttachment] = []
    var messageIDHeader: String = ""
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

struct GmailPage: Equatable, Sendable {
    var messages: [GmailMessage]
    var nextPageToken: String?
}
