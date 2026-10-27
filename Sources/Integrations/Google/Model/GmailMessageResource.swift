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
