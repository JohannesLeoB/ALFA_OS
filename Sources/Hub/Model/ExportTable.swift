public enum ExportTable: String, CaseIterable, Hashable, Sendable {
    case services
    case mailFolders
    case mailMessages
    case mailBodies
    case popMessages
    case mailOutbox
    case mailDrafts
    case chatMessages
    case chatMemory
    case notes
    case tasks
    case journal
    case privacy
    case audit

    public var sqlName: String {
        switch self {
        case .services: "inlet"
        case .mailFolders: "mail_folder"
        case .mailMessages: "mail_message"
        case .mailBodies: "mail_body"
        case .popMessages: "mail_pop"
        case .mailOutbox: "mail_outbox"
        case .mailDrafts: "mail_draft"
        case .chatMessages: "chatMessages"
        case .chatMemory: "chatMemorySummaries"
        case .notes: "assistantNotes"
        case .tasks: "assistantTasks"
        case .journal: "assistantJournal"
        case .privacy: "privacyPreferences"
        case .audit: "auditEntries"
        }
    }

    public var columns: [String] {
        switch self {
        case .services: ["id", "json"]
        case .mailFolders: ["inlet", "id", "name", "role", "position"]
        case .mailMessages:
            ["inlet", "folder", "id", "thread", "subject", "sender", "fromRaw", "toRaw", "ccRaw", "bccRaw", "replyToRaw", "snippet",
             "receivedAt", "flags", "seen", "folderIDs", "attachmentCount", "messageIDHeader", "attachments"]
        case .mailBodies: ["inlet", "id", "text", "attachments"]
        case .popMessages: ["inlet", "uid", "folder", "snippet", "seen", "flagged", "receivedAt"]
        case .mailOutbox: ["id", "inlet", "draft", "state", "attempts", "messageID"]
        case .mailDrafts: ["id", "inlet", "draft", "updatedAt"]
        case .chatMessages: ["id", "threadScopeKey", "role", "blocksJSON", "sequence", "createdAt", "userID"]
        case .chatMemory: ["userID", "scopeKey", "summaryText", "updatedAt"]
        case .notes: ["id", "body", "createdAt", "updatedAt", "projectID", "color", "userID"]
        case .tasks: ["id", "title", "done", "dueDate", "createdAt", "updatedAt", "projectID", "userID", "alarmActive"]
        case .journal: ["id", "timestamp", "projectID", "kind", "text"]
        case .privacy:
            ["id", "shareMail", "shareCalendar", "shareContacts", "shareDrive", "shareClickUp", "shareNotes", "shareTasks",
             "shareCatalogCalculation", "shareStudioKnowledge", "shareChat", "shareClockodo", "assistantDisabled", "updatedAt"]
        case .audit: ["id", "timestamp", "actorUserID", "projectID", "action", "summary", "source"]
        }
    }

    public var jsonColumns: Set<String> {
        switch self {
        case .services: ["json"]
        case .mailMessages, .mailBodies: ["attachments"]
        case .mailOutbox, .mailDrafts: ["draft"]
        case .chatMessages: ["blocksJSON"]
        default: []
        }
    }

    public var mergedColumn: String? { self == .services ? "json" : nil }

    public var droppedKeys: Set<String> {
        switch self {
        case .mailOutbox, .mailDrafts: ["data"]
        default: []
        }
    }

    public var inletColumn: String? {
        switch self {
        case .mailFolders, .mailMessages, .mailBodies, .popMessages: "inlet"
        default: nil
        }
    }

    public var orderBy: String {
        switch self {
        case .services: "rowid"
        case .mailFolders: "inlet, position"
        case .mailMessages: "inlet, folder, receivedAt DESC, id"
        case .mailBodies: "inlet, id"
        case .popMessages: "inlet, uid"
        case .mailOutbox: "position"
        case .mailDrafts: "updatedAt"
        case .chatMessages: "threadScopeKey, sequence"
        case .chatMemory: "userID, scopeKey"
        case .notes, .tasks: "createdAt, id"
        case .journal: "timestamp, id"
        case .privacy: "id"
        case .audit: "timestamp, id"
        }
    }

    public var path: String {
        switch self {
        case .services: "services.json"
        case .mailFolders: "mail/{inlet}/folders.json"
        case .mailMessages: "mail/{inlet}/messages.json"
        case .mailBodies: "mail/{inlet}/bodies.json"
        case .popMessages: "mail/{inlet}/pop-messages.json"
        case .mailOutbox: "mail/outbox.json"
        case .mailDrafts: "mail/drafts.json"
        case .chatMessages: "assistant/chat.json"
        case .chatMemory: "assistant/memory.json"
        case .notes: "assistant/notes.json"
        case .tasks: "assistant/tasks.json"
        case .journal: "assistant/journal.json"
        case .privacy: "assistant/privacy.json"
        case .audit: "activity.json"
        }
    }
}
