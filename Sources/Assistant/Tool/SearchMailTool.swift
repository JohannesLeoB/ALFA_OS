public struct SearchMailTool: ToolPort {
    static let defaultLimit = 25
    static let maxLimit = 100
    static let hiddenLabels: Set<String> = ["UNREAD", "STARRED", "IMPORTANT"]

    private let mail: any MailSearchPort

    public init(mail: any MailSearchPort) {
        self.mail = mail
    }

    public var name: String { "search_gmail" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .mail }
    public var manifestID: String { "GMAIL_SEARCH" }
    public var parameters: [ToolParameter] {
        [ToolParameter("query", required: true), ToolParameter("anzahl", kind: .integer)]
    }

    static func limit(_ input: ToolInput) -> Int {
        guard let requested = input.integer("anzahl") else { return defaultLimit }
        return max(1, min(requested, maxLimit))
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        guard query.isEmpty == false else { return .failure("assistant.common.emptyQuery") }
        do {
            let hits = try await mail.search(query: query, limit: Self.limit(input))
            guard hits.isEmpty == false else { return ToolResult(.make("assistant.mail.empty", query)) }
            return ToolResult(lines: hits.map(Self.row))
        } catch PortFailure.notConnected {
            return .failure("assistant.mail.notConnected")
        } catch {
            return .failure("assistant.mail.searchFailed", PortFailure.detail(of: error))
        }
    }

    static func row(_ hit: MailHit) -> Phrase {
        let date: Phrase = hit.receivedAt.map { .raw(ListingEngine.dateTime($0)) } ?? .make("assistant.common.noDate")
        var head: [Phrase] = [.raw("\u{2022} \(hit.subject) \u{2014} "), .make("assistant.mail.from", hit.from), .raw(" ("), date, .raw(")")]
        let places = placement(hit.labels)
        if places.isEmpty == false {
            head.append(.make("assistant.mail.placement"))
            head.append(.join(places, ", "))
        }
        if hit.attachmentNames.isEmpty == false {
            head.append(.make("assistant.mail.attachments", hit.attachmentNames.joined(separator: ", ")))
        }
        return .join([.join(head, ""), .raw("  " + hit.snippet)], "\n")
    }

    static func placement(_ labels: [String]) -> [Phrase] {
        labels.filter { hiddenLabels.contains($0) == false }.map(humanLabel)
    }

    static func humanLabel(_ id: String) -> Phrase {
        switch id {
        case "INBOX": .make("assistant.mail.label.inbox")
        case "SENT": .make("assistant.mail.label.sent")
        case "DRAFT": .make("assistant.mail.label.draft")
        case "SPAM": .make("assistant.mail.label.spam")
        case "TRASH": .make("assistant.mail.label.trash")
        case let category where category.hasPrefix("CATEGORY_"):
            .make("assistant.mail.label.category", String(category.dropFirst("CATEGORY_".count)).capitalized)
        default: .raw(id)
        }
    }
}
