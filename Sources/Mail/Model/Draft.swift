import Core

public struct Draft: Codable, Sendable, Equatable {
    public var to: String?
    var cc: String?
    var bcc: String?
    public var subject: String
    public var body: String
    public var attachments: [Attachment]
    public var inReplyTo: String?
    public var threadID: String?
    public var bodyHTML: String?
    var messageID: String?
    public var receiptTo: String?
    public var from: Participant?

    public init(to: String? = nil, cc: String? = nil, bcc: String? = nil, subject: String, body: String,
                attachments: [Attachment] = [], inReplyTo: String? = nil, threadID: String? = nil,
                bodyHTML: String? = nil, messageID: String? = nil, receiptTo: String? = nil, from: Participant? = nil) {
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.attachments = attachments
        self.inReplyTo = inReplyTo
        self.threadID = threadID
        self.bodyHTML = bodyHTML
        self.messageID = messageID
        self.receiptTo = receiptTo
        self.from = from
    }

    private enum CodingKeys: String, CodingKey {
        case to, cc, bcc, subject, body, attachments, inReplyTo, threadID, bodyHTML, messageID, receiptTo, from
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        to = try container.decodeIfPresent(String.self, forKey: .to)
        cc = try container.decodeIfPresent(String.self, forKey: .cc)
        bcc = try container.decodeIfPresent(String.self, forKey: .bcc)
        subject = try container.decode(String.self, forKey: .subject)
        body = try container.decode(String.self, forKey: .body)
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        inReplyTo = try container.decodeIfPresent(String.self, forKey: .inReplyTo)
        threadID = try container.decodeIfPresent(String.self, forKey: .threadID)
        bodyHTML = try container.decodeIfPresent(String.self, forKey: .bodyHTML)
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID)
        receiptTo = try container.decodeIfPresent(String.self, forKey: .receiptTo)
        from = try container.decodeIfPresent(Participant.self, forKey: .from)
    }
}

public struct StoredDraft: Equatable, Sendable {
    public var id: String
    public var draft: Draft

    public init(id: String, draft: Draft) {
        self.id = id
        self.draft = draft
    }
}
