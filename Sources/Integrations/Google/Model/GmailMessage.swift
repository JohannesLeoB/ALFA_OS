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
    var listUnsubscribe: String?
    var listUnsubscribePost: String?
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

struct GmailMessageResource: Decodable {
    var id: String
    var threadId: String?
    var snippet: String?
    var payload: GmailPayload?
    var labelIds: [String]?
    var internalDate: String?
}

struct GmailPayload: Decodable {
    var mimeType: String?
    var headers: [GmailHeader]?
    var body: GmailPartBody?
    var parts: [GmailPart]?
}

struct GmailPart: Decodable {
    var filename: String?
    var mimeType: String?
    var headers: [GmailHeader]?
    var body: GmailPartBody?
    var parts: [GmailPart]?
}

struct GmailHeader: Decodable {
    var name: String
    var value: String
}

struct GmailPartBody: Decodable {
    var attachmentId: String?
    var size: Int?
    var data: String?
}

struct GmailLabel: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
}

enum GmailSystemLabel {
    static let unread = "UNREAD"
    static let starred = "STARRED"
    static let inbox = "INBOX"
    static let important = "IMPORTANT"
    static let spam = "SPAM"
    static let trash = "TRASH"
    static let draft = "DRAFT"
    static let sent = "SENT"
    static let all: Set<String> = [
        unread, starred, inbox, important, spam, trash, draft, sent,
        "CATEGORY_PERSONAL", "CATEGORY_SOCIAL", "CATEGORY_PROMOTIONS", "CATEGORY_UPDATES", "CATEGORY_FORUMS", "CHAT",
    ]
}
