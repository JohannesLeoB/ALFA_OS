public struct ReadMailTool: ToolPort {
    static let bodyLimit = 6000

    private let mail: any MailSearchPort

    public init(mail: any MailSearchPort) {
        self.mail = mail
    }

    public var name: String { "read_email" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .mail }
    public var manifestID: String { "GMAIL_SEARCH" }
    public var parameters: [ToolParameter] {
        [ToolParameter("query", required: true), ToolParameter("nummer", kind: .integer)]
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        guard query.isEmpty == false else { return .failure("assistant.common.emptyQuery") }
        let index = max(1, input.integer("nummer") ?? 1)
        do {
            let hits = try await mail.search(query: query, limit: max(index, 5))
            guard hits.isEmpty == false else { return ToolResult(.make("assistant.mail.notFound", query)) }
            guard index <= hits.count else {
                return .failure("assistant.mail.noSuchHit", String(hits.count), String(index))
            }
            let message = hits[index - 1]
            let body = try await mail.body(messageID: message.id).trimmingCharacters(in: .whitespacesAndNewlines)
            let date: Phrase = message.receivedAt.map { .raw(ListingEngine.dateTime($0)) } ?? .make("assistant.common.noDate")
            let shown: Phrase
            if body.count > Self.bodyLimit {
                shown = .join([.raw(String(body.prefix(Self.bodyLimit))), .make("assistant.mail.truncated")], "\n")
            } else if body.isEmpty {
                shown = .make("assistant.mail.noBody")
            } else {
                shown = .raw(body)
            }
            return ToolResult(lines: [
                .make("assistant.mail.readSubject", message.subject),
                .join([.make("assistant.mail.readFrom", message.from), .raw(" ("), date, .raw(")")], ""),
                .raw(""),
                shown,
            ])
        } catch PortFailure.notConnected {
            return .failure("assistant.mail.notConnected")
        } catch {
            return .failure("assistant.mail.readFailed", PortFailure.detail(of: error))
        }
    }
}
