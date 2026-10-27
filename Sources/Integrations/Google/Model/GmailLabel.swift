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
