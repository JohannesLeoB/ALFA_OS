import Core
import Foundation

struct IMAPSMTPClient: MailTransportPort, PurgePort, SourcePort, SentCopyPort, SendLimitPort {
    typealias PasswordSource = @Sendable () async throws -> String
    typealias CredentialSource = @Sendable () async throws -> MailCredential

    static let summaryItems = ["UID", "FLAGS", "INTERNALDATE", "RFC822.SIZE", "ENVELOPE", "BODYSTRUCTURE",
                                       "BODY.PEEK[HEADER.FIELDS (REFERENCES)]"]
    private static let receiptSection = "HEADER.FIELDS (DISPOSITION-NOTIFICATION-TO)"
    private static let receiptItem = "BODY.PEEK[" + receiptSection + "]"
    private static let threadLimit = 20
    private static let inlineImageLimit = 2_097_152
    private static let inlineImageBudget = 8_388_608

    let account: Account
    private let credential: CredentialSource
    private let opener: StreamOpener
    private let channel: IMAPChannel
    let filesSentCopy: Bool

    init(account: Account, password: @escaping PasswordSource, channel: IMAPChannel = IMAPChannel(),
         opener: @escaping StreamOpener = StreamRouter.open) {
        self.init(account: account, credential: { .password(try await password()) }, channel: channel, opener: opener)
    }

    init(account: Account, credential: @escaping CredentialSource, channel: IMAPChannel = IMAPChannel(),
         opener: @escaping StreamOpener = StreamRouter.open, filesSentCopy: Bool = true) {
        self.account = account
        self.credential = credential
        self.channel = channel
        self.opener = opener
        self.filesSentCopy = filesSentCopy
    }

    func listFolders() async throws -> [Folder] {
        try await withIncoming { session in
            let entries = try await session.listFolders().filter(\.isSelectable)
            return zip(entries, IMAPListEntry.roles(entries)).map {
                Folder(id: $0.path, name: $0.displayName, role: $1)
            }
        }
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        let limit = max(1, maxResults)
        return try await withIncoming { session in
            let selection = try await session.select(folderID, readOnly: true)
            var criteria: [IMAPArgument] = []
            if let pageToken, let before = Int(pageToken) {
                guard before > 1 else { return MessagePage(messages: []) }
                criteria.append(.raw("UID 1:\(before - 1)"))
            }
            let text = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            criteria.append(.raw("UNDELETED"))
            if !text.isEmpty { criteria += [.raw("TEXT"), .string(text)] }
            let found = try await Self.search(session, criteria, charset: text.unicodeScalars.contains(where: { $0.value > 126 }))
            let pageUIDs = Array(found.suffix(limit))
            let more = found.count > pageUIDs.count
            let fetched = try await session.fetch(uids: pageUIDs, items: Self.summaryItems)
            let previews = await Self.previews(fetched, session: session)
            let messages = fetched.reversed().compactMap { entry -> MessageSummary? in
                guard let uid = entry.uid else { return nil }
                return Self.summary(entry, uid: uid, folder: folderID, uidValidity: selection.uidValidity, snippet: previews[uid] ?? "")
            }
            return MessagePage(messages: messages, nextPageToken: more ? pageUIDs.first.map(String.init) : nil, total: found.count)
        }
    }

    private static func search(_ session: IMAPClient, _ criteria: [IMAPArgument], charset: Bool) async throws -> [Int] {
        guard charset else { return try await session.searchUIDs(criteria) }
        do {
            return try await session.searchUIDs([.raw("CHARSET"), .raw("UTF-8")] + criteria)
        } catch MailFailure.serverRejected(let reply) where reply.uppercased().contains("BADCHARSET") {
            return try await session.searchUIDs(criteria)
        }
    }

    func fetchBody(messageID: String) async throws -> MessageBody {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailFailure.messageNotFound(messageID) }
            guard let fetched = try await session.fetch(uids: [reference.uid], items: ["UID", "BODYSTRUCTURE"]).first,
                  let structure = fetched.structure else {
                throw MailFailure.messageNotFound(messageID)
            }
            var body = MessageBody()
            if let part = structure.firstPlainText {
                body.text = try await Self.decodedText(part, session: session, uid: reference.uid)
            }
            if let part = structure.firstHTML {
                body.html = try await Self.decodedText(part, session: session, uid: reference.uid)
            }
            var budget = Self.inlineImageBudget
            for part in structure.inlineImages {
                guard let contentID = part.contentID, !contentID.isEmpty,
                      part.size <= budget, part.size <= Self.inlineImageLimit else { continue }
                let raw = try await session.fetchSection(uid: reference.uid, section: part.section)
                let decoded = MIME.decodeTransfer(raw, encoding: part.encoding)
                budget -= decoded.count
                body.inlineImages[contentID] = "data:\(part.mimeType);base64,\(decoded.base64EncodedString())"
            }
            body.attachments = structure.attachments(html: body.html, embedded: Set(body.inlineImages.keys.map { $0.lowercased() })).map(Self.info)
            return body
        }
    }

    var offersSource: Bool { true }

    func fetchSource(messageID: String) async throws -> Data {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailFailure.messageNotFound(messageID) }
            return try await session.fetchSection(uid: reference.uid, section: "")
        }
    }

    func fetchAttachment(messageID: String, attachmentID section: String) async throws -> Data {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailFailure.messageNotFound(messageID) }
            guard let fetched = try await session.fetch(uids: [reference.uid], items: ["UID", "BODYSTRUCTURE"]).first,
                  let part = fetched.structure?.leaves.first(where: { $0.section == section }) else {
                throw MailFailure.messageNotFound(messageID)
            }
            let raw = try await session.fetchSection(uid: reference.uid, section: section)
            return MIME.decodeTransfer(raw, encoding: part.encoding)
        }
    }

    func send(_ draft: Draft) async throws {
        let outgoing = try MessageEngine.build(draft, account: account,
                                               messageID: draft.messageID ?? UUID().uuidString.lowercased())
        try await SMTPSession.deliver(outgoing, settings: account.outgoing, user: user(for: account.outgoing),
                                      credential: try await currentCredential(), opener: opener)
    }

    func setFlags(messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws {
        let reference = try IMAPMessageReference.decode(messageID)
        let moveToTrash = add.contains(.deleted)
        let adding = Self.flagNames(add.subtracting([.deleted]))
        let removing = Self.flagNames(remove)
        guard moveToTrash || !adding.isEmpty || !removing.isEmpty else { return }
        try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: false)
            guard selection.uidValidity == reference.uidValidity else { throw MailFailure.messageNotFound(messageID) }
            try await session.store(uid: reference.uid, flags: adding, adding: true)
            try await session.store(uid: reference.uid, flags: removing, adding: false)
            if moveToTrash { try await Self.discard(reference, trash: nil, session: session) }
        }
    }

    private static func discard(_ reference: IMAPMessageReference, trash: String?, session: IMAPClient) async throws {
        let path: String?
        if let trash {
            path = trash
        } else {
            let entries = try await session.listFolders().filter(\.isSelectable)
            path = zip(entries, IMAPListEntry.roles(entries)).first { $1 == .trash }?.0.path
        }
        guard let path, path != reference.folder else {
            try await session.store(uid: reference.uid, flags: [Flag.deleted.imapName], adding: true)
            return
        }
        try await relocate(reference, to: path, session: session)
    }

    private static func relocate(_ reference: IMAPMessageReference, to path: String, session: IMAPClient) async throws {
        if await session.has("MOVE") {
            try await session.move(uid: reference.uid, to: path)
        } else if await session.has("UIDPLUS") {
            try await session.copy(uid: reference.uid, to: path)
            try await session.store(uid: reference.uid, flags: [Flag.deleted.imapName], adding: true)
            try await session.expunge(uid: reference.uid)
        } else {
            try await session.copy(uid: reference.uid, to: path)
            try await session.store(uid: reference.uid, flags: [Flag.deleted.imapName], adding: true)
        }
    }

    private static func removeMessage(_ reference: IMAPMessageReference, session: IMAPClient) async throws {
        let selection = try await session.select(reference.folder, readOnly: false)
        guard selection.uidValidity == reference.uidValidity else {
            throw MailFailure.messageNotFound(reference.encoded)
        }
        try await session.store(uid: reference.uid, flags: [Flag.deleted.imapName], adding: true)
        if await session.has("UIDPLUS") { try await session.expunge(uid: reference.uid) }
    }

    private func relocate(_ messageID: String, to folderID: String?, role: FolderRole) async throws {
        let reference = try IMAPMessageReference.decode(messageID)
        guard let folderID else { throw MailFailure.folderNotFound(role.rawValue) }
        try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: false)
            guard selection.uidValidity == reference.uidValidity else { throw MailFailure.messageNotFound(messageID) }
            guard folderID != reference.folder else { return }
            try await Self.relocate(reference, to: folderID, session: session)
        }
    }

    func archive(messageID: String, folderID: String?) async throws {
        try await relocate(messageID, to: folderID, role: .archive)
    }

    func move(messageID: String, toFolderID: String) async throws {
        try await relocate(messageID, to: toFolderID, role: .other)
    }

    func markSpam(messageID: String, folderID: String?) async throws {
        try await relocate(messageID, to: folderID, role: .spam)
    }

    func trash(messageID: String, folderID: String?) async throws {
        let reference = try IMAPMessageReference.decode(messageID)
        try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: false)
            guard selection.uidValidity == reference.uidValidity else { throw MailFailure.messageNotFound(messageID) }
            guard let folderID, folderID != reference.folder else {
                try await session.store(uid: reference.uid, flags: [Flag.deleted.imapName], adding: true)
                return
            }
            try await Self.relocate(reference, to: folderID, session: session)
        }
    }

    func fetchThread(messageID: String, threadID: String) async throws -> [MessageSummary] {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailFailure.messageNotFound(messageID) }
            var uids = [reference.uid]
            if threadID != messageID, (try? IMAPMessageReference.decode(threadID)) == nil {
                let id = IMAPArgument.string(threadID)
                let found = try await session.searchUIDs(
                    [.raw("UNDELETED"), .raw("OR"), .raw("OR"), .raw("HEADER"), .raw("MESSAGE-ID"), id,
                     .raw("HEADER"), .raw("REFERENCES"), id, .raw("HEADER"), .raw("IN-REPLY-TO"), id])
                uids = Array(Set(found + [reference.uid])).sorted()
            }
            let fetched = try await session.fetch(uids: Array(uids.suffix(Self.threadLimit)), items: Self.summaryItems)
            return fetched.compactMap { entry -> MessageSummary? in
                guard let uid = entry.uid else { return nil }
                return Self.summary(entry, uid: uid, folder: reference.folder, uidValidity: selection.uidValidity)
            }
        }
    }

    func saveDraft(_ draft: Draft, replacing draftID: String?, into folderID: String?) async throws -> SavedDraft {
        let token = draft.messageID ?? UUID().uuidString.lowercased()
        let message = try MessageEngine.build(draft, account: account, messageID: token, asDraft: true)
        let replaced = try draftID.map(IMAPMessageReference.decode)
        return try await withIncoming(retry: false) { session in
            guard let folderID else { throw MailFailure.folderNotFound(FolderRole.drafts.rawValue) }
            let result = try await session.append(to: folderID, flags: [Flag.draft.imapName], message: message.data)
            let created: IMAPMessageReference
            if let code = result.code, code.name == "APPENDUID", code.values.count >= 2,
               let validity = code.values[0].int, let uid = code.values[1].int {
                created = IMAPMessageReference(folder: folderID, uidValidity: validity, uid: uid)
            } else {
                let selection = try await session.select(folderID, readOnly: true)
                let found = try await session.searchUIDs([.raw("HEADER"), .raw("MESSAGE-ID"), .string(token)])
                guard let uid = found.last else { throw MailFailure.messageNotFound(token) }
                created = IMAPMessageReference(folder: folderID, uidValidity: selection.uidValidity, uid: uid)
            }
            if let replaced { try? await Self.removeMessage(replaced, session: session) }
            return SavedDraft(id: created.encoded)
        }
    }

    func fetchDraft(messageID: String) async throws -> StoredDraft {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailFailure.messageNotFound(messageID) }
            guard let fetched = try await session.fetch(uids: [reference.uid], items: ["UID", "ENVELOPE", "BODYSTRUCTURE", Self.receiptItem]).first,
                  let structure = fetched.structure else {
                throw MailFailure.messageNotFound(messageID)
            }
            let envelope = fetched.envelope
            let join: ([IMAPAddress]) -> String? = { $0.isEmpty ? nil : $0.map(\.raw).joined(separator: ", ") }
            var draft = Draft(to: join(envelope?.to ?? []), cc: join(envelope?.cc ?? []), bcc: join(envelope?.bcc ?? []),
                              subject: envelope?.subject ?? "", body: "", inReplyTo: envelope?.inReplyTo,
                              messageID: Self.localPart(envelope?.messageID),
                              receiptTo: MessageEngine.receiptAddress(fetched.sections[Self.receiptSection].map(MIME.parseHeaders)?
                                  .first { $0.name.lowercased() == "disposition-notification-to" }?.value),
                              from: MessageEngine.sender(envelope?.from.first?.raw))
            if let part = structure.firstPlainText {
                draft.body = try await Self.decodedText(part, session: session, uid: reference.uid)
            }
            if let part = structure.firstHTML {
                draft.bodyHTML = try await Self.decodedText(part, session: session, uid: reference.uid)
            }
            for part in structure.attachments(html: draft.bodyHTML, embedded: []) {
                let raw = try await session.fetchSection(uid: reference.uid, section: part.section)
                draft.attachments.append(Attachment(
                    filename: part.filename ?? part.section, mimeType: part.mimeType,
                    data: MIME.decodeTransfer(raw, encoding: part.encoding)))
            }
            return StoredDraft(id: messageID, draft: draft)
        }
    }

    func deleteDraft(id: String) async throws {
        let reference = try IMAPMessageReference.decode(id)
        try await withIncoming { session in
            try await Self.removeMessage(reference, session: session)
        }
    }

    func purge(messageID: String) async throws {
        let reference = try IMAPMessageReference.decode(messageID)
        try await withIncoming { session in
            try await Self.removeMessage(reference, session: session)
        }
    }

    func supportsPurge() async throws -> Bool {
        try await withIncoming { await $0.has("UIDPLUS") }
    }

    func sendLimit() async throws -> Int? {
        try await SMTPSession.sizeLimit(settings: account.outgoing, opener: opener)
    }

    func sendDraft(id: String) async throws {
        let stored = try await fetchDraft(messageID: id)
        try await send(stored.draft)
        try? await deleteDraft(id: id)
    }

    func fileSent(_ draft: Draft, into folderID: String?) async throws {
        guard let folderID else { throw MailFailure.folderNotFound(FolderRole.sent.rawValue) }
        let message = try MessageEngine.build(draft, account: account, messageID: draft.messageID ?? UUID().uuidString.lowercased(),
                                              asDraft: true)
        try await withIncoming(retry: false) { session in
            _ = try await session.append(to: folderID, flags: [Flag.seen.imapName], message: message.data)
        }
    }

    func wasSent(messageID: String, in folderID: String?) async throws -> Bool {
        guard let folderID else { throw MailFailure.folderNotFound(FolderRole.sent.rawValue) }
        return try await withIncoming { session in
            _ = try await session.select(folderID, readOnly: true)
            let found = try await session.searchUIDs([.raw("HEADER"), .raw("MESSAGE-ID"), .string(messageID)])
            return !found.isEmpty
        }
    }

    func changes() -> AsyncThrowingStream<Void, any Error> {
        let (stream, continuation) = AsyncThrowingStream<Void, any Error>.makeStream()
        let task = Task {
            var live: IMAPClient?
            do {
                guard account.incoming.isComplete else { throw MailFailure.accountIncomplete("incoming") }
                let session = try await openIncoming()
                live = session
                for try await _ in try await session.idle(in: "INBOX") { continuation.yield() }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
            await live?.close()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    private static func localPart(_ header: String?) -> String? {
        guard let header else { return nil }
        let bare = header.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
        return bare.split(separator: "@", maxSplits: 1).first.map(String.init)
    }

    private static func decodedText(_ part: IMAPBodyPart, session: IMAPClient, uid: Int) async throws -> String {
        let raw = try await session.fetchSection(uid: uid, section: part.section)
        let text = MIME.string(from: MIME.decodeTransfer(raw, encoding: part.encoding), charset: part.charset)
        return part.isFlowed ? MIME.unflow(text, delSp: part.deletesSpaces) : text
    }

    private static func flagNames(_ flags: Set<Flag>) -> [String] {
        flags.sorted { $0.rawValue < $1.rawValue }.map(\.imapName)
    }

    private static func info(_ part: IMAPBodyPart) -> AttachmentInfo {
        AttachmentInfo(id: part.section, filename: part.filename ?? part.section, mimeType: part.mimeType, sizeBytes: part.size)
    }

    static func summary(_ entry: IMAPFetched, uid: Int, folder: String, uidValidity: Int, snippet: String = "") -> MessageSummary {
        let envelope = entry.envelope
        let flags = Set(entry.flags.compactMap { Flag(imapName: $0) })
        let id = IMAPMessageReference(folder: folder, uidValidity: uidValidity, uid: uid).encoded
        let references = entry.sections["HEADER.FIELDS (REFERENCES)"].map(MIME.parseHeaders)?
            .first { $0.name.lowercased() == "references" }?.value
            .split(separator: " ").first.map(String.init)
        let thread = references ?? envelope?.inReplyTo ?? envelope?.messageID ?? id
        let sender = envelope?.from.first ?? envelope?.sender.first
        let attachments = (entry.structure?.attachments ?? []).map(info)
        return MessageSummary(
            id: id, threadID: thread, subject: envelope?.subject ?? "", from: sender?.display ?? "",
            fromRaw: (envelope?.from ?? []).map(\.raw).joined(separator: ", "),
            toRaw: (envelope?.to ?? []).map(\.raw).joined(separator: ", "),
            ccRaw: (envelope?.cc ?? []).map(\.raw).joined(separator: ", "),
            bccRaw: (envelope?.bcc ?? []).map(\.raw).joined(separator: ", "),
            replyToRaw: (envelope?.replyTo ?? []).map(\.raw).joined(separator: ", "),
            snippet: snippet,
            receivedAt: entry.internalDate ?? envelope?.date.flatMap(DateEngine.parseMessageDate),
            flags: flags, folderIDs: [folder], attachmentCount: attachments.count,
            attachments: attachments, messageIDHeader: envelope?.messageID ?? "")
    }

    func withIncoming<T: Sendable>(retry: Bool = true, _ body: @Sendable (IMAPClient) async throws -> T) async throws -> T {
        guard account.incoming.isComplete else { throw MailFailure.accountIncomplete("incoming") }
        return try await channel.perform(retry: retry, open: { try await openIncoming() }, body: body)
    }

    private func openIncoming() async throws -> IMAPClient {
        let secret = try await currentCredential()
        let session = try await IMAPClient.open(settings: account.incoming, opener: opener)
        do {
            try await session.authenticate(user: user(for: account.incoming), credential: secret)
        } catch {
            await session.close()
            throw error
        }
        return session
    }

    private func user(for settings: ServerSettings) -> String {
        settings.username.isEmpty ? account.address : settings.username
    }

    private func currentCredential() async throws -> MailCredential {
        let value = try await credential()
        guard !value.isEmpty else { throw MailFailure.credentialsMissing }
        return value
    }
}
