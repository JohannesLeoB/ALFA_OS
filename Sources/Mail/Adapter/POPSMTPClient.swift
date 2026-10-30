import Core
import Foundation
import Hub
import Storage

struct POPSMTPClient: MailTransportPort, SourcePort, InboxOnlyPort, ServerCopyPort, PurgePort {
    static let inboxID = "INBOX"
    static let sentID = "pop:sent"
    static let draftsID = "pop:drafts"
    static let trashID = "pop:trash"
    static let checkInterval: Duration = .seconds(300)

    let account: Account
    let store: POPStore
    private let password: @Sendable () async throws -> String
    private let opener: StreamOpener
    private let now: @Sendable () -> Date

    init(account: Account, database: SQLiteStore, password: @escaping @Sendable () async throws -> String,
         opener: @escaping StreamOpener = StreamRouter.open, now: @escaping @Sendable () -> Date = { Date() }) {
        self.account = account
        store = POPStore(database: database, inlet: account.id)
        self.password = password
        self.opener = opener
        self.now = now
    }

    var inboxOnly: Bool { true }
    var offersSource: Bool { true }

    func listFolders() async throws -> [Folder] {
        [Folder(id: Self.inboxID, name: "INBOX", role: .inbox), Folder(id: Self.draftsID, name: "Drafts", role: .drafts),
         Folder(id: Self.sentID, name: "Sent", role: .sent),
         Folder(id: Self.trashID, name: "Trash", role: .trash)]
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        let limit = max(1, maxResults)
        let text = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let all = store.entries(folderID).map { Self.summary($0) }.filter { summary in
            text.isEmpty || [summary.subject, summary.fromRaw, summary.toRaw, summary.snippet]
                .contains { $0.lowercased().contains(text) }
        }
        let offset = min(pageToken.flatMap(Int.init) ?? 0, all.count)
        let page = Array(all[offset..<min(offset + limit, all.count)])
        let more = offset + limit < all.count
        return MessagePage(messages: page, nextPageToken: more ? String(offset + limit) : nil, total: all.count)
    }

    func fetchBody(messageID: String) async throws -> MessageBody {
        RawMessageEngine.body(RawMessageEngine.parse(try raw(messageID)))
    }

    func fetchSource(messageID: String) async throws -> Data {
        try raw(messageID)
    }

    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data {
        let parsed = RawMessageEngine.parse(try raw(messageID))
        guard let part = parsed.root.leaves.first(where: { $0.section == attachmentID }) else {
            throw MailFailure.messageNotFound(messageID)
        }
        return parsed.data(part)
    }

    func send(_ draft: Draft) async throws {
        let messageID = draft.messageID ?? UUID().uuidString.lowercased()
        let outgoing = try MessageEngine.build(draft, account: account, messageID: messageID)
        try await SMTPSession.deliver(outgoing, settings: account.outgoing, user: user(account.outgoing),
                                      credential: .password(try await secret()), opener: opener)
        try? keep(outgoing.data, uid: "sent:" + messageID, folder: Self.sentID, seen: true, onServer: false)
    }

    func setFlags(messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws {
        let seen: Bool? = add.contains(.seen) ? true : (remove.contains(.seen) ? false : nil)
        let flagged: Bool? = add.contains(.flagged) ? true : (remove.contains(.flagged) ? false : nil)
        try store.setFlags(messageID, seen: seen, flagged: flagged, hidden: add.contains(.deleted) ? true : nil)
    }

    func trash(messageID: String, folderID: String?) async throws {
        guard let entry = store.entry(messageID) else { throw MailFailure.messageNotFound(messageID) }
        if entry.folder == Self.trashID {
            try await purge(messageID: messageID)
        } else {
            try store.place(messageID, in: Self.trashID)
        }
    }

    func supportsPurge() async throws -> Bool { true }

    func purge(messageID: String) async throws {
        try store.setFlags(messageID, seen: nil, flagged: nil, hidden: true)
    }

    func archive(messageID: String, folderID: String?) async throws { throw MailFailure.unsupportedCapability("archive") }

    func move(messageID: String, toFolderID: String) async throws {
        guard [Self.inboxID, Self.draftsID, Self.sentID, Self.trashID].contains(toFolderID), store.entry(messageID) != nil else {
            throw MailFailure.unsupportedCapability("move")
        }
        try store.place(messageID, in: toFolderID)
    }

    func markSpam(messageID: String, folderID: String?) async throws { throw MailFailure.unsupportedCapability("spam") }

    func fetchThread(messageID: String, threadID: String) async throws -> [MessageSummary] {
        (store.entries(Self.inboxID) + store.entries(Self.sentID)).map { Self.summary($0) }.filter { $0.threadID == threadID }
    }

    func saveDraft(_ draft: Draft, replacing draftID: String?, into folderID: String?) async throws -> SavedDraft {
        let domain = account.address.split(separator: "@").last.map(String.init) ?? "localhost"
        let uid = "draft:" + UUID().uuidString.lowercased()
        try keep(MessageEngine.buildRaw(draft, domain: domain), uid: uid, folder: Self.draftsID, seen: true, onServer: false)
        if let draftID { try store.remove(draftID) }
        return SavedDraft(id: uid)
    }

    func fetchDraft(messageID: String) async throws -> StoredDraft {
        let parsed = RawMessageEngine.parse(try raw(messageID))
        let header = { (name: String) -> String? in
            parsed.header(name).flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        }
        var draft = Draft(to: header("To"), cc: header("Cc"), bcc: header("Bcc"), subject: header("Subject") ?? "", body: "",
                          inReplyTo: header("In-Reply-To"),
                          messageID: header("Message-ID").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")) }
                              .flatMap { $0.split(separator: "@").first.map(String.init) },
                          receiptTo: MessageEngine.receiptAddress(header("Disposition-Notification-To")),
                          from: MessageEngine.sender(header("From")))
        if let part = parsed.root.firstPlainText { draft.body = parsed.text(part) }
        if let part = parsed.root.firstHTML { draft.bodyHTML = parsed.text(part) }
        draft.attachments = parsed.root.attachments.map {
            Attachment(filename: $0.filename ?? $0.section, mimeType: $0.mimeType, data: parsed.data($0))
        }
        return StoredDraft(id: messageID, draft: draft)
    }

    func deleteDraft(id: String) async throws {
        try store.remove(id)
    }

    func sendDraft(id: String) async throws {
        try await send(try await fetchDraft(messageID: id).draft)
        try store.remove(id)
    }

    func wasSent(messageID: String, in folderID: String?) async throws -> Bool {
        store.entry("sent:" + messageID) != nil
    }

    func expire(_ policy: ServerCopy, now: Date) async throws {
        let due = store.onServer().filter { entry in
            switch policy {
            case .keep: false
            case .deleted: entry.hidden || entry.folder == Self.trashID
            case .day, .week, .month:
                entry.fetchedAt.addingTimeInterval(Double(policy.days ?? 0) * 86_400) <= now
            }
        }.map(\.uid)
        guard !due.isEmpty else { return }
        try await withSession { session in
            let numbers = Dictionary(try await session.identifiers().map { ($0.uid, $0.number) }) { first, _ in first }
            for uid in due {
                if let number = numbers[uid] { try await session.delete(number) }
            }
        }
        try store.leftServer(Set(due))
    }

    func changes() -> AsyncThrowingStream<Void, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                try? await Task.sleep(for: Self.checkInterval)
                if !Task.isCancelled { continuation.yield() }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func keep(_ data: Data, uid: String, folder: String, seen: Bool, onServer: Bool) throws {
        let parsed = RawMessageEngine.parse(data)
        let summary = RawMessageEngine.summary(parsed, id: uid, folder: folder, flags: [], received: nil)
        let head = Data(data.prefix(Self.headEnd(data)))
        let entry = POPEntry(uid: uid, folder: folder, head: head, snippet: summary.snippet, attachments: summary.attachments,
                             seen: seen, flagged: false, hidden: false, onServer: onServer,
                             receivedAt: summary.receivedAt ?? now(), fetchedAt: now())
        try store.insert(entry, raw: data)
    }

    static func summary(_ entry: POPEntry) -> MessageSummary {
        let parsed = RawMessageEngine.parse(entry.head)
        var summary = RawMessageEngine.summary(parsed, id: entry.uid, folder: entry.folder, flags: entry.flags,
                                               received: entry.receivedAt)
        summary.snippet = entry.snippet
        summary.attachments = entry.attachments
        summary.attachmentCount = entry.attachments.count
        return summary
    }

    static func headEnd(_ data: Data) -> Int {
        let bytes = [UInt8](data)
        var index = 0
        while index + 1 < bytes.count {
            if bytes[index] == 10, bytes[index + 1] == 10 { return index + 2 }
            if bytes[index] == 10, index + 2 < bytes.count, bytes[index + 1] == 13, bytes[index + 2] == 10 { return index + 3 }
            index += 1
        }
        return bytes.count
    }

    private func raw(_ messageID: String) throws -> Data {
        guard let data = store.raw(messageID) else { throw MailFailure.messageNotFound(messageID) }
        return data
    }

    func withSession<T: Sendable>(_ body: @Sendable (POPSession) async throws -> T) async throws -> T {
        guard account.incoming.isComplete else { throw MailFailure.accountIncomplete("incoming") }
        let secret = try await secret()
        let session = try await POPSession.open(settings: account.incoming, opener: opener)
        do {
            try await session.authenticate(user: user(account.incoming), secret: secret)
            let result = try await body(session)
            await session.quit()
            return result
        } catch {
            await session.close()
            throw error
        }
    }

    private func user(_ settings: ServerSettings) -> String {
        settings.username.isEmpty ? account.address : settings.username
    }

    private func secret() async throws -> String {
        let value = try await password()
        guard !value.isEmpty else { throw MailFailure.credentialsMissing }
        return value
    }
}

extension POPSMTPClient: MirrorPort {
    var ranges: [MailboxRange] { MailboxRange.allCases }

    func startCursor() async throws -> String? { nil }

    func listIDs(folderID: String, since: Date?, limit: Int?) async throws -> MirrorListing {
        var waiting: [String] = []
        if folderID == Self.inboxID {
            let known = store.known()
            let listed = try await withSession { try await $0.identifiers() }
            try store.leftServer(Set(store.onServer().map(\.uid)).subtracting(listed.map(\.uid)))
            waiting = listed.filter { !known.contains($0.uid) }.sorted { $0.number > $1.number }.map(\.uid)
        }
        let local = store.entries(folderID).filter { entry in since.map { entry.receivedAt >= $0 } ?? true }.map(\.uid)
        var ids = waiting + local
        var older = false
        if let limit, ids.count > limit {
            ids = Array(ids.prefix(limit))
            older = true
        } else if since != nil {
            older = store.entries(folderID).count > local.count
        }
        return MirrorListing(ids: ids, hasOlder: older)
    }

    func fetchSummaries(folderID: String, ids: [String]) async throws -> [MessageSummary] {
        let missing = ids.filter { store.entry($0) == nil }
        if folderID == Self.inboxID, !missing.isEmpty {
            try await withSession { session in
                let numbers = Dictionary(try await session.identifiers().map { ($0.uid, $0.number) }) { first, _ in first }
                for uid in missing {
                    guard let number = numbers[uid] else { continue }
                    try keep(try await session.retrieve(number), uid: uid, folder: Self.inboxID, seen: false, onServer: true)
                }
            }
        }
        return ids.compactMap { store.entry($0) }.filter { !$0.hidden && $0.folder == folderID }.map { Self.summary($0) }
    }

    func refreshFlags(folderID: String, known: [String], cursor: String?) async throws -> FlagRefresh {
        var flags: [String: Set<Flag>] = [:]
        for id in known {
            guard let entry = store.entry(id), !entry.hidden else { continue }
            flags[id] = entry.flags
        }
        return FlagRefresh(flags: flags)
    }
}

actor POPSession {
    private static let implicitPort = 995
    private static let explicitPort = 110
    private static let lineLimit = 2_000_000

    private let reader: StreamBuffer
    private(set) var capabilities: [String] = []

    private init(reader: StreamBuffer) {
        self.reader = reader
    }

    static func open(settings: ServerSettings, opener: StreamOpener = StreamRouter.open) async throws -> POPSession {
        guard settings.security != .none else { throw MailFailure.tlsUnavailable }
        let port = settings.port ?? (settings.security == .ssl ? implicitPort : explicitPort)
        let stream = try await opener(settings.host, port, settings.security)
        let session = POPSession(reader: StreamBuffer(stream: stream))
        do {
            _ = try await session.status()
            try await session.loadCapabilities()
            if settings.security == .starttls {
                guard await session.capabilities.contains(where: { $0.uppercased() == "STLS" }) else {
                    throw MailFailure.tlsUnavailable
                }
                _ = try await session.command("STLS")
                try await session.reader.upgradeToTLS()
                try await session.loadCapabilities()
            }
        } catch {
            await session.close()
            throw error
        }
        return session
    }

    func authenticate(user: String, secret: String) async throws {
        let sasl = capabilities.first { $0.uppercased().hasPrefix("SASL ") }?.uppercased().split(separator: " ") ?? []
        do {
            if sasl.contains("PLAIN") {
                _ = try await command("AUTH PLAIN " + Data("\0\(user)\0\(secret)".utf8).base64EncodedString())
            } else {
                _ = try await command("USER " + user)
                _ = try await command("PASS " + secret)
            }
        } catch MailFailure.serverRejected(let text) {
            throw MailFailure.authenticationRejected(text)
        }
    }

    func identifiers() async throws -> [(number: Int, uid: String)] {
        _ = try await command("UIDL")
        return try await multiline().compactMap { line in
            let words = MIME.string(from: line, charset: nil).split(separator: " ")
            guard words.count >= 2, let number = Int(words[0]) else { return nil }
            return (number, String(words[1]))
        }
    }

    func top(_ number: Int, lines: Int) async throws -> Data {
        _ = try await command("TOP \(number) \(lines)")
        return Self.joined(try await multiline())
    }

    func retrieve(_ number: Int) async throws -> Data {
        _ = try await command("RETR \(number)")
        return Self.joined(try await multiline())
    }

    func delete(_ number: Int) async throws {
        _ = try await command("DELE \(number)")
    }

    func quit() async {
        _ = try? await command("QUIT")
        await close()
    }

    func close() async {
        await reader.close()
    }

    private func loadCapabilities() async throws {
        do {
            _ = try await command("CAPA")
            capabilities = try await multiline().map { MIME.string(from: $0, charset: nil) }
        } catch MailFailure.serverRejected {
            capabilities = []
        }
    }

    private func command(_ line: String) async throws -> String {
        guard !line.contains("\r"), !line.contains("\n") else { throw MailFailure.malformedResponse("popCommand") }
        try await reader.write(Data((line + "\r\n").utf8))
        return try await status()
    }

    private func status() async throws -> String {
        let line = MIME.string(from: try await reader.readLine(), charset: nil)
        if line.hasPrefix("+OK") { return String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
        if line.hasPrefix("-ERR") { throw MailFailure.serverRejected(String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)) }
        throw MailFailure.malformedResponse("popStatus")
    }

    private func multiline() async throws -> [Data] {
        var lines: [Data] = []
        while true {
            var line = try await reader.readLine()
            if line == Data([46]) { return lines }
            if line.first == 46 { line = line.dropFirst() }
            lines.append(Data(line))
            if lines.count > Self.lineLimit { throw MailFailure.malformedResponse("popLength") }
        }
    }

    static func joined(_ lines: [Data]) -> Data {
        var data = Data()
        for line in lines {
            data.append(line)
            data.append(contentsOf: [13, 10])
        }
        return data
    }
}
