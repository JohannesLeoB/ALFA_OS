import Foundation

public struct DraftAttachment: Codable, Sendable, Equatable {
    public var filename: String
    public var mimeType: String
    public var data: Data

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

public struct EmailDraft: Codable, Sendable, Equatable {
    public var to: String?

    public var cc: String?

    public var bcc: String?
    public var subject: String
    public var body: String
    public var attachments: [DraftAttachment]

    public var inReplyTo: String?

    public var threadID: String?
    public var bodyHTML: String?

    public init(to: String? = nil, cc: String? = nil, bcc: String? = nil, subject: String, body: String,
                attachments: [DraftAttachment] = [], inReplyTo: String? = nil, threadID: String? = nil,
                bodyHTML: String? = nil) {
        self.bodyHTML = bodyHTML
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.attachments = attachments
        self.inReplyTo = inReplyTo
        self.threadID = threadID
    }

    private enum CodingKeys: String, CodingKey { case to, cc, bcc, subject, body, attachments, inReplyTo, threadID }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.to = try c.decodeIfPresent(String.self, forKey: .to)
        self.cc = try c.decodeIfPresent(String.self, forKey: .cc)
        self.bcc = try c.decodeIfPresent(String.self, forKey: .bcc)
        self.subject = try c.decode(String.self, forKey: .subject)
        self.body = try c.decode(String.self, forKey: .body)
        self.attachments = try c.decodeIfPresent([DraftAttachment].self, forKey: .attachments) ?? []
        self.inReplyTo = try c.decodeIfPresent(String.self, forKey: .inReplyTo)
        self.threadID = try c.decodeIfPresent(String.self, forKey: .threadID)
    }

    public var headline: String {
        let empfaenger = (to?.isEmpty == false) ? to! : "(kein Empfänger)"
        return "\(subject) · an \(empfaenger)"
    }

    public static func signaturAnhaengen(an body: String, signatur: String?) -> String {
        let getrimmt = (signatur ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard getrimmt.isEmpty == false else { return body }
        return body.isEmpty ? "\n\n-- \n\(getrimmt)" : "\(body)\n\n-- \n\(getrimmt)"
    }

    public func mitAngehaengterSignatur(_ signatur: String?) -> EmailDraft {
        var neu = self
        neu.body = Self.signaturAnhaengen(an: body, signatur: signatur)
        return neu
    }
}

public enum DraftCreateOutcome: Sendable, Equatable {
    case created(String)
    case failed(String)
}

public enum MailSendOutcome: Sendable, Equatable {
    case sent(String)
    case failed(String)
    case permissionRequired
}
