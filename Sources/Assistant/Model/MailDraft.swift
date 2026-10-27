public struct MailDraft: Codable, Sendable, Equatable {
    var to: String?
    var cc: String?
    var bcc: String?
    var subject: String
    var body: String

    init(to: String? = nil, cc: String? = nil, bcc: String? = nil, subject: String, body: String) {
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
    }
}
