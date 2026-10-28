import Core
import Foundation
import Mail

struct GmailClient: GmailFetchPort, GmailWritePort, GmailDraftPort, GmailLabelPort {
    static let root = "https://gmail.googleapis.com/gmail/v1/users/me"
    static let draftListSize = "100"

    let requests: RequestClient
    let policy: RequestPolicy

    init(requests: RequestClient, policy: RequestPolicy = .standard) {
        self.requests = requests
        self.policy = policy
    }

    private var messages: String { Self.root + "/messages" }
    private var drafts: String { Self.root + "/drafts" }

    private func detailURL(_ messageID: String) throws -> URL {
        try RequestClient.url(messages + "/\(messageID)", query: [URLQueryItem(name: "format", value: "full")])
    }

    func listMessages(query: String, maxResults: Int, pageToken: String?) async throws -> GmailPage {
        var items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "maxResults", value: String(maxResults))]
        if let pageToken, !pageToken.isEmpty { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        let list = try MessageParser.listPage(from: try await requests.send(RequestClient.url(messages, query: items)))
        guard !list.ids.isEmpty else { return GmailPage(messages: [], nextPageToken: nil) }
        let details = try await fetchDetails(list.ids)
        return GmailPage(messages: details.sorted { $0.0 < $1.0 }.map(\.1), nextPageToken: list.nextPageToken)
    }

    private func fetchDetails(_ ids: [String]) async throws -> [(Int, GmailMessage)] {
        try await withThrowingTaskGroup(of: (Int, GmailMessage).self) { group in
            var results: [(Int, GmailMessage)] = []
            var next = 0
            func launch() {
                let index = next
                next += 1
                group.addTask { (index, try await fetchDetail(ids[index])) }
            }
            while next < ids.count, next < policy.maxConcurrentDetails { launch() }
            while let finished = try await group.next() {
                results.append(finished)
                if next < ids.count { launch() }
            }
            return results
        }
    }

    private func fetchDetail(_ id: String) async throws -> GmailMessage {
        let url = try detailURL(id)
        var attempt = 1
        while true {
            do {
                return try MessageParser.message(from: try await requests.send(url))
            } catch GoogleFailure.api(_, let fault) where fault.isRetryable && attempt < policy.maxAttempts {
                try await Task.sleep(for: policy.delay(afterAttempt: attempt))
                attempt += 1
            }
        }
    }

    func fetchMailBody(messageID: String) async throws -> GmailMailBody {
        BodyParser.mailBody(from: try await requests.send(detailURL(messageID)))
    }

    func fetchRaw(messageID: String) async throws -> Data {
        struct Body: Decodable { var raw: String? }
        let url = try RequestClient.url(messages + "/\(messageID)", query: [URLQueryItem(name: "format", value: "raw")])
        guard let body = try? JSONDecoder().decode(Body.self, from: try await requests.send(url)), let raw = body.raw,
              let data = Base64Engine.decodeURL(raw) else {
            throw GoogleFailure.decodingFailed
        }
        return data
    }

    func fetchBody(messageID: String) async throws -> String {
        BodyParser.plain(from: try await requests.send(detailURL(messageID)))
    }

    func fetchThread(threadID: String, maxMessages: Int) async throws -> [GmailMessage] {
        let url = try RequestClient.url(Self.root + "/threads/\(threadID)", query: [
            URLQueryItem(name: "format", value: "full"),
            URLQueryItem(name: "maxResults", value: String(maxMessages)),
        ])
        return MessageParser.thread(from: try await requests.send(url))
    }

    func downloadAttachment(messageID: String, attachmentID: String) async throws -> Data {
        struct Body: Decodable { var data: String? }
        let url = try RequestClient.url(messages + "/\(messageID)/attachments/\(attachmentID)")
        let data = try await requests.send(url)
        guard let body = try? JSONDecoder().decode(Body.self, from: data), let raw = body.data else {
            throw GoogleFailure.decodingFailed
        }
        return Base64Engine.decodeURL(raw) ?? Data()
    }

    func createDraft(_ draft: Draft) async throws -> String {
        let data = try await requests.send(RequestClient.url(drafts), method: "POST",
                                           json: ["message": DraftMimeEngine.payload(draft)])
        return DraftParser.draftID(from: data) ?? ""
    }

    func sendMessage(_ draft: Draft) async throws {
        try await requests.send(RequestClient.url(messages + "/send"), method: "POST", json: DraftMimeEngine.payload(draft))
    }

    func getDraft(id: String) async throws -> Draft {
        let url = try RequestClient.url(drafts + "/\(id)", query: [URLQueryItem(name: "format", value: "full")])
        guard let content = DraftParser.content(from: try await requests.send(url)) else {
            throw GoogleFailure.decodingFailed
        }
        var attachments: [Attachment] = []
        for ref in content.attachmentRefs {
            let bytes = try await downloadAttachment(messageID: content.messageID, attachmentID: ref.attachmentID)
            attachments.append(Attachment(filename: ref.filename, mimeType: ref.mimeType, data: bytes))
        }
        return content.draft(with: attachments)
    }

    func updateDraft(id: String, draft: Draft) async throws -> String {
        let data = try await requests.send(RequestClient.url(drafts + "/\(id)"), method: "PUT",
                                           json: ["message": DraftMimeEngine.payload(draft)])
        return DraftParser.draftID(from: data) ?? id
    }

    func sendDraft(id: String) async throws {
        try await requests.send(RequestClient.url(drafts + "/send"), method: "POST", json: ["id": id])
    }

    func deleteDraft(id: String) async throws {
        try await requests.send(RequestClient.url(drafts + "/\(id)"), method: "DELETE")
    }

    func listDraftIDMap() async throws -> [String: String] {
        let url = try RequestClient.url(drafts, query: [URLQueryItem(name: "maxResults", value: Self.draftListSize)])
        return DraftParser.idMap(from: try await requests.send(url))
    }

    func modifyLabels(messageID: String, add: [String], remove: [String]) async throws {
        var body: [String: [String]] = [:]
        if !add.isEmpty { body["addLabelIds"] = add }
        if !remove.isEmpty { body["removeLabelIds"] = remove }
        try await requests.send(RequestClient.url(messages + "/\(messageID)/modify"), method: "POST", json: body)
    }

    func trashMessage(messageID: String) async throws {
        try await requests.send(RequestClient.url(messages + "/\(messageID)/trash"), method: "POST")
    }

    func listLabels() async throws -> [GmailLabel] {
        MessageParser.labels(from: try await requests.send(RequestClient.url(Self.root + "/labels")))
    }
}
