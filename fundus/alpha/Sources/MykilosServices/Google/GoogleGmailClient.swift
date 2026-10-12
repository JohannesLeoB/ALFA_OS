import Foundation
import MykilosKit

public struct GmailAttachment: Equatable, Sendable {
    public var attachmentID: String
    public var filename: String
    public var mimeType: String
    public var sizeBytes: Int

    public init(attachmentID: String, filename: String, mimeType: String, sizeBytes: Int) {
        self.attachmentID = attachmentID
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
    }
}

public struct GmailLabel: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var backgroundColor: String?
    public var textColor: String?
    public init(id: String, name: String, backgroundColor: String? = nil, textColor: String? = nil) {
        self.id = id
        self.name = name
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }
}

public struct GmailPage: Equatable, Sendable {
    public var messages: [GoogleGmailMessage]
    public var nextPageToken: String?
    public var resultSizeEstimate: Int?
    public init(messages: [GoogleGmailMessage], nextPageToken: String? = nil, resultSizeEstimate: Int? = nil) {
        self.messages = messages
        self.nextPageToken = nextPageToken
        self.resultSizeEstimate = resultSizeEstimate
    }
}

public struct GmailMailBody: Equatable, Sendable {
    public var text: String?
    public var html: String?
    public var inlineImages: [String: String]
    public init(text: String? = nil, html: String? = nil, inlineImages: [String: String] = [:]) {
        self.text = text
        self.html = html
        self.inlineImages = inlineImages
    }
    public var bestText: String { text ?? html.map(GoogleGmailClient.stripHTML) ?? "" }
}

public struct GmailHistoryDelta: Equatable, Sendable {
    public var added: [String]
    public var deleted: [String]
    public var labelsSet: [String: [String]]
    public var historyId: String?
    public init(added: [String] = [], deleted: [String] = [], labelsSet: [String: [String]] = [:], historyId: String? = nil) {
        self.added = added
        self.deleted = deleted
        self.labelsSet = labelsSet
        self.historyId = historyId
    }
}

public struct GmailProfile: Equatable, Sendable {
    public var emailAddress: String
    public var messagesTotal: Int
    public var historyId: String
    public init(emailAddress: String, messagesTotal: Int, historyId: String) {
        self.emailAddress = emailAddress
        self.messagesTotal = messagesTotal
        self.historyId = historyId
    }
}

public struct GoogleGmailMessage: Identifiable, Equatable, Sendable {
    public var id: String
    public var threadID: String
    public var subject: String

    public var from: String

    public var fromRaw: String

    public var toRaw: String

    public var ccRaw: String
    public var snippet: String
    public var receivedAt: Date?
    public var labels: [String]
    public var attachments: [GmailAttachment]

    public var messageIDHeader: String
    public var historyID: String = ""

    public init(
        id: String,
        threadID: String = "",
        subject: String,
        from: String,
        fromRaw: String = "",
        toRaw: String = "",
        ccRaw: String = "",
        snippet: String,
        receivedAt: Date?,
        labels: [String] = [],
        attachments: [GmailAttachment] = [],
        messageIDHeader: String = "",
        historyID: String = ""
    ) {
        self.id = id
        self.threadID = threadID
        self.subject = subject
        self.from = from
        self.fromRaw = fromRaw
        self.toRaw = toRaw
        self.ccRaw = ccRaw
        self.snippet = snippet
        self.receivedAt = receivedAt
        self.labels = labels
        self.attachments = attachments
        self.messageIDHeader = messageIDHeader
        self.historyID = historyID
    }

    public static func extractEmail(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = trimmed.firstIndex(of: "<"),
           let close = trimmed.lastIndex(of: ">"),
           open < close {
            return String(trimmed[trimmed.index(after: open)..<close])
        }
        return trimmed
    }

    public var senderEmail: String {
        let email = Self.extractEmail(from: fromRaw)
        return email.isEmpty ? from : email
    }

    public var replySubject: String {
        subject.hasPrefix("Re: ") || subject.hasPrefix("re: ") ? subject : "Re: \(subject)"
    }

    public var forwardSubject: String {
        "Fwd: \(subject)"
    }

    public func quotedBody(_ body: String) -> String {
        let dateStr = receivedAt.map {
            DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short)
        } ?? ""
        let header = dateStr.isEmpty ? "\n\n— \(from) schrieb:\n" : "\n\n— Am \(dateStr) schrieb \(from):\n"
        let quoted = body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")
        return header + quoted
    }
}

public enum GoogleGmailError: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed
}

extension GoogleGmailError {
    public var needsPermission: Bool {
        switch self {
        case .notConnected, .httpError(401), .httpError(403): true
        default: false
        }
    }
}

public protocol GoogleGmailFetching: Sendable {
    func searchMessages(query: String, maxResults: Int) async throws -> [GoogleGmailMessage]

    func listMessages(query: String, maxResults: Int, pageToken: String?) async throws -> GmailPage

    func fetchMailBody(messageID: String) async throws -> GmailMailBody

    func fetchProfile() async throws -> GmailProfile

    func fetchBody(messageID: String) async throws -> String

    func fetchThread(threadID: String, maxMessages: Int) async throws -> [GoogleGmailMessage]

    func downloadAttachment(messageID: String, attachmentID: String) async throws -> Data
}

public extension GoogleGmailFetching {
    func listMessages(query: String, maxResults: Int, pageToken: String?) async throws -> GmailPage {
        GmailPage(messages: try await searchMessages(query: query, maxResults: maxResults))
    }
    func fetchMailBody(messageID: String) async throws -> GmailMailBody {
        GmailMailBody(text: try await fetchBody(messageID: messageID))
    }
    func fetchProfile() async throws -> GmailProfile {
        throw GoogleGmailError.invalidResponse
    }
    func fetchBody(messageID: String) async throws -> String {
        throw GoogleGmailError.invalidResponse
    }
    func fetchThread(threadID: String, maxMessages: Int) async throws -> [GoogleGmailMessage] { [] }
    func downloadAttachment(messageID: String, attachmentID: String) async throws -> Data {
        throw GoogleGmailError.invalidResponse
    }
}

public protocol GoogleGmailWriting: Sendable {
    func createDraft(_ draft: EmailDraft) async throws -> String

    func sendMessage(_ draft: EmailDraft) async throws
}

public protocol GoogleGmailDraftEditing: Sendable {
    func getDraft(id: String) async throws -> EmailDraft

    func updateDraft(id: String, draft: EmailDraft) async throws -> String

    func sendDraft(id: String) async throws

    func listDraftIDMap() async throws -> [String: String]
}

public protocol GoogleGmailLabelModifying: Sendable {
    func modifyLabels(messageID: String, add: [String], remove: [String]) async throws

    func trashMessage(messageID: String) async throws

    func listLabels() async throws -> [GmailLabel]
}

public extension GoogleGmailLabelModifying {
    func listLabels() async throws -> [GmailLabel] { [] }
    func listLabelsWithColors() async throws -> [GmailLabel] { try await listLabels() }
    func markSpam(messageID: String) async throws {
        try await modifyLabels(messageID: messageID, add: ["SPAM"], remove: ["INBOX"])
    }
}

public enum GmailSystemLabel {
    public static let unread = "UNREAD"
    public static let starred = "STARRED"
    public static let inbox = "INBOX"
    public static let important = "IMPORTANT"
    public static let spam = "SPAM"
    public static let trash = "TRASH"
    public static let draft = "DRAFT"
    public static let sent = "SENT"
    public static let all: Set<String> = [unread, starred, inbox, important, spam, trash, draft, sent,
                                          "CATEGORY_PERSONAL", "CATEGORY_SOCIAL", "CATEGORY_PROMOTIONS",
                                          "CATEGORY_UPDATES", "CATEGORY_FORUMS", "CHAT"]
}

public struct GoogleGmailClient: GoogleGmailFetching, GoogleGmailWriting, GoogleGmailLabelModifying,
                                 GoogleGmailDraftEditing {
    private let tokenProvider: GoogleAccessTokenProviding
    private let session: URLSession
    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
    private let draftsURL = "https://gmail.googleapis.com/gmail/v1/users/me/drafts"
    private let labelsURL = "https://gmail.googleapis.com/gmail/v1/users/me/labels"

    public init(
        tokenProvider: GoogleAccessTokenProviding = GoogleAccessTokenProvider(),
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
    }

    public func searchMessages(query: String, maxResults: Int = 10) async throws -> [GoogleGmailMessage] {
        try await listMessages(query: query, maxResults: maxResults, pageToken: nil).messages
    }

    public func listMessages(query: String, maxResults: Int, pageToken: String?) async throws -> GmailPage {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }

        guard let listURL = Self.buildListURL(query: query, maxResults: maxResults, pageToken: pageToken, baseURL: baseURL) else {
            throw GoogleGmailError.invalidResponse
        }

        var listRequest = URLRequest(url: listURL)
        listRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (listData, listResponse) = try await session.data(for: listRequest)
        guard let listHTTP = listResponse as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(listHTTP.statusCode) else { throw GoogleGmailError.httpError(listHTTP.statusCode) }

        let listPage = try Self.parseListPage(from: listData)
        let messageIDs = listPage.ids
        guard !messageIDs.isEmpty else { return GmailPage(messages: [], nextPageToken: nil, resultSizeEstimate: listPage.estimate) }

        let indexedMessages: [(Int, GoogleGmailMessage)] = try await withThrowingTaskGroup(
            of: (Int, GoogleGmailMessage?).self
        ) { group in
            for (index, id) in messageIDs.enumerated() {
                group.addTask {
                    guard let detailURL = Self.buildDetailURL(messageID: id, baseURL: self.baseURL) else {
                        return (index, nil)
                    }
                    var detailRequest = URLRequest(url: detailURL)
                    detailRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    guard let (detailData, detailResponse) = try? await self.session.data(for: detailRequest),
                          let detailHTTP = detailResponse as? HTTPURLResponse,
                          (200...299).contains(detailHTTP.statusCode) else {
                        return (index, nil)
                    }
                    return (index, try? Self.parseMessage(from: detailData))
                }
            }
            var results: [(Int, GoogleGmailMessage)] = []
            for try await (index, message) in group {
                if let message { results.append((index, message)) }
            }
            return results
        }
        return GmailPage(messages: indexedMessages.sorted { $0.0 < $1.0 }.map(\.1),
                         nextPageToken: listPage.nextPageToken,
                         resultSizeEstimate: listPage.estimate)
    }

    public func fetchMailBody(messageID: String) async throws -> GmailMailBody {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildDetailURL(messageID: messageID, baseURL: baseURL) else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        return Self.parseMailBody(from: data)
    }

    public func fetchMessage(messageID: String) async throws -> GoogleGmailMessage {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildDetailURL(messageID: messageID, baseURL: baseURL) else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        return try Self.parseMessage(from: data)
    }

    public func fetchHistory(startHistoryId: String) async throws -> GmailHistoryDelta {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        var delta = GmailHistoryDelta()
        var pageToken: String?
        var pages = 0
        repeat {
            var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/history")
            var items = [URLQueryItem(name: "startHistoryId", value: startHistoryId),
                         URLQueryItem(name: "maxResults", value: "500")]
            for t in ["messageAdded", "messageDeleted", "labelAdded", "labelRemoved"] {
                items.append(URLQueryItem(name: "historyTypes", value: t))
            }
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components?.queryItems = items
            guard let url = components?.url else { throw GoogleGmailError.invalidResponse }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
            guard let decoded = try? JSONDecoder().decode(GmailHistoryResponse.self, from: data) else {
                throw GoogleGmailError.decodingFailed
            }
            for h in decoded.history ?? [] {
                for a in h.messagesAdded ?? [] { if let id = a.message?.id { delta.added.append(id) } }
                for d in h.messagesDeleted ?? [] { if let id = d.message?.id { delta.deleted.append(id) } }
                for l in (h.labelsAdded ?? []) + (h.labelsRemoved ?? []) {
                    if let m = l.message, let ids = m.labelIds { delta.labelsSet[m.id] = ids }
                }
            }
            if let hid = decoded.historyId { delta.historyId = hid }
            pageToken = decoded.nextPageToken
            pages += 1
        } while pageToken != nil && pages < 20
        let gel = Set(delta.deleted)
        delta.added = Array(NSOrderedSet(array: delta.added.filter { gel.contains($0) == false })) as? [String] ?? delta.added
        return delta
    }

    public func fetchProfile() async throws -> GmailProfile {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile") else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        struct P: Decodable { var emailAddress: String; var messagesTotal: Int?; var historyId: String? }
        guard let p = try? JSONDecoder().decode(P.self, from: data) else { throw GoogleGmailError.decodingFailed }
        return GmailProfile(emailAddress: p.emailAddress, messagesTotal: p.messagesTotal ?? 0, historyId: p.historyId ?? "")
    }

    public func listLabelsWithColors() async throws -> [GmailLabel] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        let basis = try await listLabels()
        return try await withThrowingTaskGroup(of: GmailLabel.self) { group in
            for label in basis {
                group.addTask {
                    guard let url = URL(string: "\(self.labelsURL)/\(label.id)") else { return label }
                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    guard let (data, response) = try? await self.session.data(for: request),
                          let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                          let detail = try? JSONDecoder().decode(GmailLabelsResponse.GmailLabelEntry.self, from: data)
                    else { return label }
                    return GmailLabel(id: label.id, name: label.name,
                                      backgroundColor: detail.color?.backgroundColor,
                                      textColor: detail.color?.textColor)
                }
            }
            var out: [GmailLabel] = []
            for try await l in group { out.append(l) }
            return out.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    public func fetchBody(messageID: String) async throws -> String {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildDetailURL(messageID: messageID, baseURL: baseURL) else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        return Self.parseBody(from: data)
    }

    public func downloadAttachment(messageID: String, attachmentID: String) async throws -> Data {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }

        let urlString = "\(baseURL)/\(messageID)/attachments/\(attachmentID)"
        guard let url = URL(string: urlString) else { throw GoogleGmailError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }

        struct AttachmentBody: Decodable { var data: String? }
        guard let body = try? JSONDecoder().decode(AttachmentBody.self, from: data),
              let raw = body.data else { throw GoogleGmailError.decodingFailed }
        return Self.decodeBase64URL(raw) ?? Data()
    }

    static func decodeBase64URL(_ s: String) -> Data? {
        var padded = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
    }

    public func createDraft(_ draft: EmailDraft) async throws -> String {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = URL(string: draftsURL) else { throw GoogleGmailError.invalidResponse }
        let raw = Self.base64URL(Data(Self.buildMIMEMultipart(draft).utf8))
        let payload = try JSONSerialization.data(withJSONObject: ["message": Self.messageRawPayload(raw: raw, draft: draft)])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        let decoded = try? JSONDecoder().decode(GmailDraftResponse.self, from: data)
        return decoded?.id ?? ""
    }

    public func sendMessage(_ draft: EmailDraft) async throws {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = URL(string: baseURL + "/send") else { throw GoogleGmailError.invalidResponse }
        let raw = Self.base64URL(Data(Self.buildMIMEMultipart(draft).utf8))
        let payload = try JSONSerialization.data(withJSONObject: Self.messageRawPayload(raw: raw, draft: draft))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
    }

    public func getDraft(id: String) async throws -> EmailDraft {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildDraftDetailURL(id: id, draftsURL: draftsURL) else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        guard let parsed = Self.parseDraftContent(from: data) else { throw GoogleGmailError.decodingFailed }

        var attachments: [DraftAttachment] = []
        for ref in parsed.attachmentRefs {
            let bytes = try await downloadAttachment(messageID: parsed.messageID, attachmentID: ref.attachmentID)
            attachments.append(DraftAttachment(filename: ref.filename, mimeType: ref.mimeType, data: bytes))
        }
        return EmailDraft(to: parsed.to, cc: parsed.cc, bcc: parsed.bcc,
                          subject: parsed.subject, body: parsed.body, attachments: attachments,
                          inReplyTo: parsed.inReplyTo, threadID: parsed.threadID)
    }

    public func updateDraft(id: String, draft: EmailDraft) async throws -> String {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildDraftDetailURL(id: id, draftsURL: draftsURL) else {
            throw GoogleGmailError.invalidResponse
        }
        let raw = Self.base64URL(Data(Self.buildMIMEMultipart(draft).utf8))
        let payload = try JSONSerialization.data(withJSONObject: ["message": Self.messageRawPayload(raw: raw, draft: draft)])
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        let decoded = try? JSONDecoder().decode(GmailDraftResponse.self, from: data)
        return decoded?.id ?? id
    }

    public func sendDraft(id: String) async throws {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildDraftSendURL(draftsURL: draftsURL) else {
            throw GoogleGmailError.invalidResponse
        }
        let payload = try JSONSerialization.data(withJSONObject: ["id": id])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
    }

    public func deleteDraft(id: String) async throws {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildDraftDetailURL(id: id, draftsURL: draftsURL) else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
    }

    public func listDraftIDMap() async throws -> [String: String] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildDraftListURL(draftsURL: draftsURL) else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        return Self.parseDraftIDMap(from: data)
    }

    public func modifyLabels(messageID: String, add: [String] = [], remove: [String] = []) async throws {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildModifyURL(messageID: messageID, baseURL: baseURL) else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.buildModifyBody(add: add, remove: remove))

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
    }

    public func trashMessage(messageID: String) async throws {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = Self.buildTrashURL(messageID: messageID, baseURL: baseURL) else {
            throw GoogleGmailError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
    }

    public func listLabels() async throws -> [GmailLabel] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        guard let url = URL(string: labelsURL) else { throw GoogleGmailError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleGmailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleGmailError.httpError(http.statusCode) }
        return Self.parseLabels(from: data)
    }

    static func parseLabels(from data: Data) -> [GmailLabel] {
        guard let decoded = try? JSONDecoder().decode(GmailLabelsResponse.self, from: data) else { return [] }
        return (decoded.labels ?? [])
            .filter { $0.type == "user" }
            .compactMap { l in l.id.flatMap { id in l.name.map {
                GmailLabel(id: id, name: $0, backgroundColor: l.color?.backgroundColor, textColor: l.color?.textColor) } } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func buildModifyURL(messageID: String, baseURL: String) -> URL? {
        URL(string: "\(baseURL)/\(messageID)/modify")
    }

    static func buildTrashURL(messageID: String, baseURL: String) -> URL? {
        URL(string: "\(baseURL)/\(messageID)/trash")
    }

    static func buildModifyBody(add: [String], remove: [String]) -> [String: [String]] {
        var body: [String: [String]] = [:]
        if add.isEmpty == false { body["addLabelIds"] = add }
        if remove.isEmpty == false { body["removeLabelIds"] = remove }
        return body
    }

    static func threadingHeaderLines(_ draft: EmailDraft) -> [String] {
        guard let ref = draft.inReplyTo?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty else { return [] }
        return ["In-Reply-To: \(ref)", "References: \(ref)"]
    }

    static func messageRawPayload(raw: String, draft: EmailDraft) -> [String: Any] {
        var m: [String: Any] = ["raw": raw]
        if let t = draft.threadID?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { m["threadId"] = t }
        return m
    }

    static func base64Lines(_ data: Data) -> String {
        let b64 = data.base64EncodedString()
        return stride(from: 0, to: b64.count, by: 76).map { i -> String in
            let start = b64.index(b64.startIndex, offsetBy: i)
            let end = b64.index(start, offsetBy: 76, limitedBy: b64.endIndex) ?? b64.endIndex
            return String(b64[start..<end])
        }.joined(separator: "\r\n")
    }

    static func addressHeaderLines(_ draft: EmailDraft) -> [String] {
        var lines: [String] = []
        if let to = draft.to?.trimmingCharacters(in: .whitespacesAndNewlines), to.isEmpty == false {
            lines.append("To: \(to)")
        }
        if let cc = draft.cc?.trimmingCharacters(in: .whitespacesAndNewlines), !cc.isEmpty {
            lines.append("Cc: \(cc)")
        }
        if let bcc = draft.bcc?.trimmingCharacters(in: .whitespacesAndNewlines), !bcc.isEmpty {
            lines.append("Bcc: \(bcc)")
        }
        lines.append("Subject: \(encodeHeader(draft.subject))")
        lines.append(contentsOf: threadingHeaderLines(draft))
        lines.append("MIME-Version: 1.0")
        return lines
    }

    static func bodyPartLines(_ draft: EmailDraft, boundaryBase: String) -> [String] {
        guard let html = draft.bodyHTML, html.isEmpty == false else {
            return ["Content-Type: text/plain; charset=\"UTF-8\"",
                    "Content-Transfer-Encoding: base64",
                    "",
                    base64Lines(Data(draft.body.utf8))]
        }
        let alt = "myk_alt_\(boundaryBase)"
        return ["Content-Type: multipart/alternative; boundary=\"\(alt)\"",
                "",
                "--\(alt)",
                "Content-Type: text/plain; charset=\"UTF-8\"",
                "Content-Transfer-Encoding: base64",
                "",
                base64Lines(Data(draft.body.utf8)),
                "--\(alt)",
                "Content-Type: text/html; charset=\"UTF-8\"",
                "Content-Transfer-Encoding: base64",
                "",
                base64Lines(Data(html.utf8)),
                "--\(alt)--"]
    }

    static func buildMIME(_ draft: EmailDraft) -> String {
        var lines = addressHeaderLines(draft)
        lines.append(contentsOf: bodyPartLines(draft, boundaryBase: String(abs(draft.subject.hashValue))))
        return lines.joined(separator: "\r\n")
    }

    static func buildMIMEMultipart(_ draft: EmailDraft) -> String {
        guard !draft.attachments.isEmpty else { return buildMIME(draft) }
        let boundary = "myk_boundary_\(abs(draft.subject.hashValue))"
        var lines: [String] = []
        if let to = draft.to?.trimmingCharacters(in: .whitespacesAndNewlines), !to.isEmpty {
            lines.append("To: \(to)")
        }
        if let cc = draft.cc?.trimmingCharacters(in: .whitespacesAndNewlines), !cc.isEmpty {
            lines.append("Cc: \(cc)")
        }
        if let bcc = draft.bcc?.trimmingCharacters(in: .whitespacesAndNewlines), !bcc.isEmpty {
            lines.append("Bcc: \(bcc)")
        }
        lines.append("Subject: \(encodeHeader(draft.subject))")
        lines.append(contentsOf: threadingHeaderLines(draft))
        lines.append("MIME-Version: 1.0")
        lines.append("Content-Type: multipart/mixed; boundary=\"\(boundary)\"")
        lines.append("")

        lines.append("--\(boundary)")
        lines.append(contentsOf: bodyPartLines(draft, boundaryBase: String(abs(draft.subject.hashValue))))

        for attachment in draft.attachments {
            lines.append("--\(boundary)")
            lines.append("Content-Type: \(attachment.mimeType); name=\"\(attachment.filename)\"")
            lines.append("Content-Transfer-Encoding: base64")
            lines.append("Content-Disposition: attachment; filename=\"\(attachment.filename)\"")
            lines.append("")
            lines.append(base64Lines(attachment.data))
        }
        lines.append("--\(boundary)--")
        return lines.joined(separator: "\r\n")
    }

    public func fetchThread(threadID: String, maxMessages: Int = 10) async throws -> [GoogleGmailMessage] {
        guard let accessToken = try? await tokenProvider.validAccessToken() else {
            throw GoogleGmailError.notConnected
        }
        let urlStr = "https://gmail.googleapis.com/gmail/v1/users/me/threads/\(threadID)?format=full&maxResults=\(maxMessages)"
        guard let url = URL(string: urlStr) else { throw GoogleGmailError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GoogleGmailError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return Self.parseThreadMessages(from: data)
    }

    static func parseThreadMessages(from data: Data) -> [GoogleGmailMessage] {
        struct MsgRes: Decodable {
            var id: String
            var threadId: String?
            var snippet: String?
            var labelIds: [String]?
            var payload: PayloadRes?
            struct PayloadRes: Decodable {
                var headers: [HdrRes]?
                var parts: [GmailPart]?
            }
            struct HdrRes: Decodable { var name: String; var value: String }
        }
        struct TR: Decodable { var messages: [MsgRes]? }
        guard let tr = try? JSONDecoder().decode(TR.self, from: data) else { return [] }
        return (tr.messages ?? []).map { r in
            let headers = r.payload?.headers ?? []
            let subject = headers.first(where: { $0.name == "Subject" })?.value ?? "(kein Betreff)"
            let fromRawValue = headers.first(where: { $0.name == "From" })?.value ?? ""
            let toRawValue = headers.first(where: { $0.name == "To" })?.value ?? ""
            let ccRawValue = headers.first(where: { $0.name == "Cc" })?.value ?? ""
            let dateStr = headers.first(where: { $0.name == "Date" })?.value
            return GoogleGmailMessage(
                id: r.id,
                threadID: r.threadId ?? "",
                subject: subject,
                from: extractSenderName(from: fromRawValue),
                fromRaw: fromRawValue,
                toRaw: toRawValue,
                ccRaw: ccRawValue,
                snippet: Self.decodeEntities(r.snippet ?? ""),
                receivedAt: dateStr.flatMap { parseEmailDate($0) },
                labels: r.labelIds ?? [],
                attachments: extractAttachments(from: r.payload?.parts ?? [])
            )
        }
    }

    static func encodeHeader(_ value: String) -> String {
        if value.allSatisfy({ $0.isASCII }) { return value }
        return "=?UTF-8?B?\(Data(value.utf8).base64EncodedString())?="
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func parseBody(from data: Data) -> String {
        guard let resource = try? JSONDecoder().decode(GmailMessageResource.self, from: data) else { return "" }
        if let plain = firstPart(resource.payload, mime: "text/plain") { return plain }
        if let html = firstPart(resource.payload, mime: "text/html") { return stripHTML(html) }
        return resource.snippet ?? ""
    }

    static func parseMailBody(from data: Data) -> GmailMailBody {
        guard let resource = try? JSONDecoder().decode(GmailMessageResource.self, from: data) else { return GmailMailBody() }
        let plain = firstPart(resource.payload, mime: "text/plain")
        let html = firstPart(resource.payload, mime: "text/html")
        var inline: [String: String] = [:]
        collectInlineImages(resource.payload?.parts ?? [], into: &inline)
        if plain == nil, html == nil {
            return GmailMailBody(text: resource.snippet, html: nil, inlineImages: inline)
        }
        return GmailMailBody(text: plain, html: html, inlineImages: inline)
    }

    private static func collectInlineImages(_ parts: [GmailPart], into map: inout [String: String]) {
        for part in parts {
            if let sub = part.parts { collectInlineImages(sub, into: &map) }
            guard let attachmentID = part.body?.attachmentId, attachmentID.isEmpty == false else { continue }
            let cid = part.headers?.first(where: { $0.name.lowercased() == "content-id" })?.value
                .trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
            if let cid, cid.isEmpty == false { map[cid] = attachmentID }
        }
    }

    private static func firstPart(_ payload: GmailPayload?, mime: String) -> String? {
        guard let payload else { return nil }
        if payload.mimeType == mime, let decoded = decodeBodyData(payload.body?.data) { return decoded }
        for part in payload.parts ?? [] {
            if let found = firstPartInPart(part, mime: mime) { return found }
        }
        return nil
    }

    private static func firstPartInPart(_ part: GmailPart, mime: String) -> String? {
        if part.mimeType == mime, let decoded = decodeBodyData(part.body?.data) { return decoded }
        for sub in part.parts ?? [] {
            if let found = firstPartInPart(sub, mime: mime) { return found }
        }
        return nil
    }

    private static func decodeBodyData(_ data: String?) -> String? {
        guard let data, data.isEmpty == false else { return nil }
        var s = data.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        guard let bytes = Data(base64Encoded: s) else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    static func stripHTML(_ html: String) -> String {
        var roh = html
        for tag in ["style", "script", "head", "title"] {
            roh = roh.replacingOccurrences(
                of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)\\s*>",
                with: " ", options: [.regularExpression, .caseInsensitive])
        }
        roh = roh.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: " ", options: .regularExpression)
        roh = roh.replacingOccurrences(of: "<br\\s*/?>", with: "\n",
                                       options: [.regularExpression, .caseInsensitive])
        roh = roh.replacingOccurrences(of: "</(p|div|tr|li|h[1-6])\\s*>", with: "\n",
                                       options: [.regularExpression, .caseInsensitive])
        let out = decodeEntities(roh.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression))
        return out.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[ \\t]*\n[ \\t]*", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ text: String) -> String {
        var out = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
        if let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);") {
            let matches = regex.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed()
            for match in matches {
                guard let whole = Range(match.range, in: out),
                      let hexFlag = Range(match.range(at: 1), in: out),
                      let digits = Range(match.range(at: 2), in: out) else { continue }
                let radix = out[hexFlag].isEmpty ? 10 : 16
                guard let value = UInt32(out[digits], radix: radix), let scalar = Unicode.Scalar(value) else { continue }
                out.replaceSubrange(whole, with: String(Character(scalar)))
            }
        }
        return out.replacingOccurrences(of: "&amp;", with: "&")
    }

    static func buildListURL(query: String, maxResults: Int, pageToken: String? = nil, baseURL: String) -> URL? {
        var components = URLComponents(string: baseURL)
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        if let pageToken, pageToken.isEmpty == false {
            items.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components?.queryItems = items
        return components?.url
    }

    struct ListPage { var ids: [String]; var nextPageToken: String?; var estimate: Int? }

    static func parseListPage(from data: Data) throws -> ListPage {
        do {
            let decoded = try JSONDecoder().decode(GmailListResponse.self, from: data)
            return ListPage(ids: (decoded.messages ?? []).map(\.id),
                            nextPageToken: decoded.nextPageToken,
                            estimate: decoded.resultSizeEstimate)
        } catch {
            throw GoogleGmailError.decodingFailed
        }
    }

    static func buildDetailURL(messageID: String, baseURL: String) -> URL? {
        var components = URLComponents(string: baseURL + "/\(messageID)")

        components?.queryItems = [
            URLQueryItem(name: "format", value: "full")
        ]
        return components?.url
    }

    static func buildDraftDetailURL(id: String, draftsURL: String) -> URL? {
        var components = URLComponents(string: draftsURL + "/\(id)")
        components?.queryItems = [URLQueryItem(name: "format", value: "full")]
        return components?.url
    }

    static func buildDraftSendURL(draftsURL: String) -> URL? {
        URL(string: draftsURL + "/send")
    }

    static func buildDraftListURL(draftsURL: String) -> URL? {
        var components = URLComponents(string: draftsURL)
        components?.queryItems = [URLQueryItem(name: "maxResults", value: "100")]
        return components?.url
    }

    static func parseDraftIDMap(from data: Data) -> [String: String] {
        guard let decoded = try? JSONDecoder().decode(GmailDraftListResponse.self, from: data) else { return [:] }
        var map: [String: String] = [:]
        for d in decoded.drafts ?? [] {
            if let draftID = d.id, let messageID = d.message?.id { map[messageID] = draftID }
        }
        return map
    }

    static func parseDraftContent(from data: Data) -> ParsedDraftContent? {
        guard let decoded = try? JSONDecoder().decode(GmailDraftFullResponse.self, from: data),
              let message = decoded.message else { return nil }
        let headers = message.payload?.headers ?? []
        func header(_ name: String) -> String? {
            let v = headers.first(where: { $0.name.lowercased() == name.lowercased() })?.value
            return (v?.isEmpty == false) ? v : nil
        }
        let body: String = {
            if let plain = firstPart(message.payload, mime: "text/plain") { return plain }
            if let html = firstPart(message.payload, mime: "text/html") { return stripHTML(html) }
            return message.snippet ?? ""
        }()
        let refs = extractAttachments(from: message.payload?.parts ?? []).map {
            ParsedDraftContent.AttachmentRef(attachmentID: $0.attachmentID, filename: $0.filename, mimeType: $0.mimeType)
        }
        let threadID = message.threadId?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedDraftContent(
            messageID: message.id, to: header("To"), cc: header("Cc"), bcc: header("Bcc"),
            subject: header("Subject") ?? "", body: body, attachmentRefs: refs,
            threadID: (threadID?.isEmpty == false) ? threadID : nil,
            inReplyTo: header("In-Reply-To") ?? header("References"))
    }

    static func parseMessageIDs(from data: Data) throws -> [String] {
        do {
            let decoded = try JSONDecoder().decode(GmailListResponse.self, from: data)
            return (decoded.messages ?? []).map(\.id)
        } catch {
            throw GoogleGmailError.decodingFailed
        }
    }

    static func parseMessage(from data: Data) throws -> GoogleGmailMessage {
        do {
            let decoded = try JSONDecoder().decode(GmailMessageResource.self, from: data)
            return mapResource(decoded)
        } catch {
            throw GoogleGmailError.decodingFailed
        }
    }

    private static func mapResource(_ resource: GmailMessageResource) -> GoogleGmailMessage {
        let headers = resource.payload?.headers ?? []
        let subject = headers.first(where: { $0.name == "Subject" })?.value ?? "(kein Betreff)"
        let fromRawValue = headers.first(where: { $0.name == "From" })?.value ?? ""
        let toRawValue = headers.first(where: { $0.name == "To" })?.value ?? ""
        let ccRawValue = headers.first(where: { $0.name == "Cc" })?.value ?? ""
        let dateString = headers.first(where: { $0.name == "Date" })?.value
        let messageIDHeader = headers.first(where: { $0.name.lowercased() == "message-id" })?.value ?? ""

        let attachments = extractAttachments(from: resource.payload?.parts ?? [])

        return GoogleGmailMessage(
            id: resource.id,
            threadID: resource.threadId ?? "",
            subject: subject,
            from: extractSenderName(from: fromRawValue),
            fromRaw: fromRawValue,
            toRaw: toRawValue,
            ccRaw: ccRawValue,
            snippet: Self.decodeEntities(resource.snippet ?? ""),
            receivedAt: dateString.flatMap { parseEmailDate($0) } ?? internalDate(resource.internalDate),
            labels: resource.labelIds ?? [],
            attachments: attachments,
            messageIDHeader: messageIDHeader,
            historyID: resource.historyId ?? ""
        )
    }

    private static func extractAttachments(from parts: [GmailPart]) -> [GmailAttachment] {
        var result: [GmailAttachment] = []
        for part in parts {
            if let subParts = part.parts {
                result += extractAttachments(from: subParts)
            }
            guard
                let filename = part.filename, !filename.isEmpty,
                let attachmentID = part.body?.attachmentId, !attachmentID.isEmpty
            else { continue }
            result.append(GmailAttachment(
                attachmentID: attachmentID,
                filename: filename,
                mimeType: part.mimeType ?? "application/octet-stream",
                sizeBytes: part.body?.size ?? 0
            ))
        }
        return result
    }

    static func extractSenderName(from raw: String) -> String {
        if let angleBracket = raw.firstIndex(of: "<") {
            let name = raw[raw.startIndex..<angleBracket].trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = name.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return cleaned.isEmpty ? raw : cleaned
        }
        return raw
    }

    private static func parseEmailDate(_ string: String) -> Date? {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(")"), let open = text.firstIndex(of: "(") {
            text = String(text[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in [
            "EEE, d MMM yyyy HH:mm:ss Z",
            "d MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss z",
            "EEE, d MMM yyyy HH:mm Z",
            "d MMM yyyy HH:mm Z"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static func internalDate(_ string: String?) -> Date? {
        guard let string, let milliseconds = Double(string) else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }
}

private struct GmailHistoryResponse: Decodable {
    var history: [Entry]?
    var nextPageToken: String?
    var historyId: String?
    struct Entry: Decodable {
        var messagesAdded: [Change]?
        var messagesDeleted: [Change]?
        var labelsAdded: [Change]?
        var labelsRemoved: [Change]?
    }
    struct Change: Decodable {
        var message: Msg?
        struct Msg: Decodable { var id: String; var labelIds: [String]? }
    }
}

private struct GmailListResponse: Decodable {
    var messages: [GmailMessageRef]?
    var nextPageToken: String?
    var resultSizeEstimate: Int?
}

private struct GmailMessageRef: Decodable {
    var id: String
}

private struct GmailMessageResource: Decodable {
    var id: String
    var threadId: String?
    var snippet: String?
    var payload: GmailPayload?
    var labelIds: [String]?
    var historyId: String?
    var internalDate: String?
}

private struct GmailPayload: Decodable {
    var mimeType: String?
    var headers: [GmailHeader]?
    var body: GmailPartBody?
    var parts: [GmailPart]?
}

private struct GmailPart: Decodable {
    var filename: String?
    var mimeType: String?
    var headers: [GmailHeader]?
    var body: GmailPartBody?
    var parts: [GmailPart]?
}

private struct GmailPartBody: Decodable {
    var attachmentId: String?
    var size: Int?
    var data: String?
}

private struct GmailDraftResponse: Decodable {
    var id: String?
}

private struct GmailLabelsResponse: Decodable {
    var labels: [GmailLabelEntry]?
    struct GmailLabelEntry: Decodable {
        var id: String?
        var name: String?
        var type: String?
        var color: LabelColor?
        struct LabelColor: Decodable { var backgroundColor: String?; var textColor: String? }
    }
}

private struct GmailDraftFullResponse: Decodable {
    var id: String?
    var message: GmailMessageResource?
}

private struct GmailDraftListResponse: Decodable {
    var drafts: [GmailDraftRef]?
    struct GmailDraftRef: Decodable {
        var id: String?
        var message: GmailMessageRef?
        struct GmailMessageRef: Decodable { var id: String? }
    }
}

struct ParsedDraftContent: Equatable {
    var messageID: String
    var to: String?
    var cc: String?
    var bcc: String?
    var subject: String
    var body: String
    var attachmentRefs: [AttachmentRef]

    var threadID: String?

    var inReplyTo: String?
    struct AttachmentRef: Equatable {
        var attachmentID: String
        var filename: String
        var mimeType: String
    }
}

private struct GmailHeader: Decodable {
    var name: String
    var value: String
}
