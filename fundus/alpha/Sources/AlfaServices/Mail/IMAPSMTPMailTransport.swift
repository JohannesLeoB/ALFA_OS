import Foundation
import AlfaKit

public struct IMAPSMTPMailTransport: MailTransport {
    public typealias AccessTokenSource = @Sendable () async throws -> String

    public let account: MailAccount
    public typealias PasswordSource = @Sendable () async throws -> String

    private let accessToken: AccessTokenSource?
    private let password: PasswordSource?
    private let opener: MailStreamOpener

    public init(account: MailAccount, accessToken: AccessTokenSource? = nil, password: PasswordSource? = nil) {
        self.init(account: account, accessToken: accessToken, password: password, opener: MailStreams.open)
    }

    init(account: MailAccount, accessToken: AccessTokenSource?, password: PasswordSource?, opener: @escaping MailStreamOpener) {
        self.account = account
        self.opener = opener
        self.password = password
        if let accessToken {
            self.accessToken = accessToken
        } else if account.provider == .gmail {
            let provider = GoogleAccessTokenProvider()
            self.accessToken = { try await provider.validAccessToken() }
        } else {
            self.accessToken = nil
        }
    }

    public func listFolders() async throws -> [MailFolder] {
        try await withIncoming { session in
            try await session.listFolders().filter(\.isSelectable).map {
                MailFolder(id: $0.path, name: $0.displayName, role: $0.role)
            }
        }
    }

    public func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        let limit = max(1, maxResults)
        return try await withIncoming { session in
            let folders = try await session.listFolders()
            guard folders.contains(where: { $0.path == folderID && $0.isSelectable }) else {
                throw MailTransportError.folderNotFound(folderID)
            }
            let selection = try await session.select(folderID, readOnly: true)
            var criteria: [IMAPArgument] = []
            if let pageToken, let before = Int(pageToken) {
                guard before > 1 else { return MailMessagePage(messages: []) }
                criteria.append(.raw("UID 1:\(before - 1)"))
            }
            let text = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                if criteria.isEmpty { criteria.append(.raw("ALL")) }
            } else {
                if text.unicodeScalars.contains(where: { $0.value > 126 }) {
                    criteria.insert(contentsOf: [.raw("CHARSET"), .raw("UTF-8")], at: 0)
                }
                criteria += [.raw("TEXT"), .string(text)]
            }
            let found = try await session.searchUIDs(criteria)
            let pageUIDs = Array(found.suffix(limit))
            let more = found.count > pageUIDs.count
            let fetched = try await session.fetch(uids: pageUIDs, items: Self.summaryItems)
            let messages = fetched.reversed().compactMap { entry -> MailMessageSummary? in
                guard let uid = entry.uid else { return nil }
                return Self.summary(entry, uid: uid, folder: folderID, uidValidity: selection.uidValidity)
            }
            return MailMessagePage(messages: messages, nextPageToken: more ? pageUIDs.first.map(String.init) : nil)
        }
    }

    public func fetchBody(messageID: String) async throws -> MailMessageBody {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailTransportError.messageNotFound(messageID) }
            guard let fetched = try await session.fetch(uids: [reference.uid], items: ["UID", "BODYSTRUCTURE"]).first,
                  let structure = fetched.structure else {
                throw MailTransportError.messageNotFound(messageID)
            }
            var body = MailMessageBody()
            if let part = structure.firstPlainText {
                body.text = try await Self.decodedText(part, session: session, uid: reference.uid)
            }
            if let part = structure.firstHTML {
                body.html = try await Self.decodedText(part, session: session, uid: reference.uid)
            }
            var budget = Self.inlineImageBudget
            for part in structure.inlineImages {
                guard let contentID = part.contentID, contentID.isEmpty == false,
                      part.size <= budget, part.size <= Self.inlineImageLimit else { continue }
                let raw = try await session.fetchSection(uid: reference.uid, section: part.section)
                let decoded = MailMIME.decodeTransfer(raw, encoding: part.encoding)
                budget -= decoded.count
                body.inlineImages[contentID] = "data:\(part.mimeType);base64,\(decoded.base64EncodedString())"
            }
            body.attachments = structure.attachments.map {
                MailAttachmentInfo(id: $0.section, filename: $0.filename ?? $0.section, mimeType: $0.mimeType, sizeBytes: $0.size)
            }
            return body
        }
    }

    public func fetchAttachment(messageID: String, attachmentID section: String) async throws -> Data {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailTransportError.messageNotFound(messageID) }
            guard let fetched = try await session.fetch(uids: [reference.uid], items: ["UID", "BODYSTRUCTURE"]).first,
                  let part = fetched.structure?.leaves.first(where: { $0.section == section }) else {
                throw MailTransportError.messageNotFound(messageID)
            }
            let raw = try await session.fetchSection(uid: reference.uid, section: section)
            return MailMIME.decodeTransfer(raw, encoding: part.encoding)
        }
    }

    public func send(_ draft: EmailDraft) async throws {
        let outgoing = try MailMessageBuilder.build(draft, account: account)
        guard account.outgoing.isComplete else { throw MailTransportError.accountIncomplete("outgoing") }
        let credential = try await credential(for: account.outgoing)
        let session = try await SMTPSession.open(settings: account.outgoing, opener: opener)
        do {
            try await session.authenticate(credential)
            try await session.send(from: outgoing.sender, recipients: outgoing.recipients, message: outgoing.data)
        } catch {
            await session.close()
            throw error
        }
        await session.quit()
    }

    public func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {
        let reference = try IMAPMessageReference.decode(messageID)
        let moveToTrash = add.contains(.deleted)
        let adding = Self.flagNames(add.subtracting([.deleted]))
        let removing = Self.flagNames(remove)
        guard moveToTrash || adding.isEmpty == false || removing.isEmpty == false else { return }
        try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: false)
            guard selection.uidValidity == reference.uidValidity else { throw MailTransportError.messageNotFound(messageID) }
            try await session.store(uid: reference.uid, flags: adding, adding: true)
            try await session.store(uid: reference.uid, flags: removing, adding: false)
            if moveToTrash { try await Self.discard(reference, session: session) }
        }
    }

    private static func discard(_ reference: IMAPMessageReference, session: IMAPSession) async throws {
        let folders = try await session.listFolders()
        guard let trash = folders.first(where: { $0.role == .trash && $0.isSelectable }),
              trash.path != reference.folder else {
            try await session.store(uid: reference.uid, flags: ["\\Deleted"], adding: true)
            return
        }
        try await relocate(reference, to: trash.path, session: session)
    }

    private static func relocate(_ reference: IMAPMessageReference, to path: String, session: IMAPSession) async throws {
        if await session.has("MOVE") {
            try await session.move(uid: reference.uid, to: path)
        } else if await session.has("UIDPLUS") {
            try await session.copy(uid: reference.uid, to: path)
            try await session.store(uid: reference.uid, flags: ["\\Deleted"], adding: true)
            try await session.expunge(uid: reference.uid)
        } else {
            try await session.copy(uid: reference.uid, to: path)
            try await session.store(uid: reference.uid, flags: ["\\Deleted"], adding: true)
        }
    }

    private static func removeMessage(_ reference: IMAPMessageReference, session: IMAPSession) async throws {
        let selection = try await session.select(reference.folder, readOnly: false)
        guard selection.uidValidity == reference.uidValidity else {
            throw MailTransportError.messageNotFound(reference.encoded)
        }
        try await session.store(uid: reference.uid, flags: ["\\Deleted"], adding: true)
        if await session.has("UIDPLUS") { try await session.expunge(uid: reference.uid) }
    }

    private enum Destination: Sendable {
        case role(MailFolderRole)
        case path(String)
    }

    private func relocate(_ messageID: String, to destination: Destination) async throws {
        let reference = try IMAPMessageReference.decode(messageID)
        try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: false)
            guard selection.uidValidity == reference.uidValidity else { throw MailTransportError.messageNotFound(messageID) }
            let folders = try await session.listFolders().filter(\.isSelectable)
            let target: IMAPListEntry?
            let name: String
            switch destination {
            case .role(let role):
                target = folders.first { $0.role == role }
                name = role.rawValue
            case .path(let path):
                target = folders.first { $0.path == path }
                name = path
            }
            guard let target else { throw MailTransportError.folderNotFound(name) }
            guard target.path != reference.folder else { return }
            try await Self.relocate(reference, to: target.path, session: session)
        }
    }

    public func archive(messageID: String) async throws {
        try await relocate(messageID, to: .role(.archive))
    }

    public func move(messageID: String, toFolderID: String) async throws {
        try await relocate(messageID, to: .path(toFolderID))
    }

    public func markSpam(messageID: String) async throws {
        try await relocate(messageID, to: .role(.spam))
    }

    public func trash(messageID: String) async throws {
        let reference = try IMAPMessageReference.decode(messageID)
        try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: false)
            guard selection.uidValidity == reference.uidValidity else { throw MailTransportError.messageNotFound(messageID) }
            try await Self.discard(reference, session: session)
        }
    }

    public func fetchThread(messageID: String, threadID: String) async throws -> [MailMessageSummary] {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailTransportError.messageNotFound(messageID) }
            var uids = [reference.uid]
            if threadID != messageID, (try? IMAPMessageReference.decode(threadID)) == nil {
                let id = IMAPArgument.string(threadID)
                let found = try await session.searchUIDs(
                    [.raw("OR"), .raw("OR"), .raw("HEADER"), .raw("MESSAGE-ID"), id,
                     .raw("HEADER"), .raw("REFERENCES"), id, .raw("HEADER"), .raw("IN-REPLY-TO"), id])
                uids = Array(Set(found + [reference.uid])).sorted()
            }
            let fetched = try await session.fetch(uids: Array(uids.suffix(Self.threadLimit)), items: Self.summaryItems)
            return fetched.compactMap { entry -> MailMessageSummary? in
                guard let uid = entry.uid else { return nil }
                return Self.summary(entry, uid: uid, folder: reference.folder, uidValidity: selection.uidValidity)
            }
        }
    }

    public func saveDraft(_ draft: EmailDraft, replacing draftID: String?) async throws -> String {
        let token = UUID().uuidString.lowercased()
        let message = try MailMessageBuilder.build(draft, account: account, messageID: token, asDraft: true)
        let replaced = try draftID.map(IMAPMessageReference.decode)
        return try await withIncoming { session in
            let folders = try await session.listFolders()
            guard let drafts = folders.first(where: { $0.role == .drafts && $0.isSelectable }) else {
                throw MailTransportError.folderNotFound(MailFolderRole.drafts.rawValue)
            }
            let result = try await session.append(to: drafts.path, flags: ["\\Draft"], message: message.data)
            let created: IMAPMessageReference
            if let code = result.code, code.name == "APPENDUID", code.values.count >= 2,
               let validity = code.values[0].int, let uid = code.values[1].int {
                created = IMAPMessageReference(folder: drafts.path, uidValidity: validity, uid: uid)
            } else {
                let selection = try await session.select(drafts.path, readOnly: true)
                let found = try await session.searchUIDs([.raw("HEADER"), .raw("MESSAGE-ID"), .string(token)])
                guard let uid = found.last else { throw MailTransportError.messageNotFound(token) }
                created = IMAPMessageReference(folder: drafts.path, uidValidity: selection.uidValidity, uid: uid)
            }
            if let replaced { try? await Self.removeMessage(replaced, session: session) }
            return created.encoded
        }
    }

    public func fetchDraft(messageID: String) async throws -> MailStoredDraft {
        let reference = try IMAPMessageReference.decode(messageID)
        return try await withIncoming { session in
            let selection = try await session.select(reference.folder, readOnly: true)
            guard selection.uidValidity == reference.uidValidity else { throw MailTransportError.messageNotFound(messageID) }
            guard let fetched = try await session.fetch(uids: [reference.uid], items: ["UID", "ENVELOPE", "BODYSTRUCTURE"]).first,
                  let structure = fetched.structure else {
                throw MailTransportError.messageNotFound(messageID)
            }
            let envelope = fetched.envelope
            let join: ([IMAPAddress]) -> String? = { $0.isEmpty ? nil : $0.map(\.raw).joined(separator: ", ") }
            var draft = EmailDraft(to: join(envelope?.to ?? []), cc: join(envelope?.cc ?? []), bcc: join(envelope?.bcc ?? []),
                                   subject: envelope?.subject ?? "", body: "", inReplyTo: envelope?.inReplyTo)
            if let part = structure.firstPlainText {
                draft.body = try await Self.decodedText(part, session: session, uid: reference.uid)
            }
            if let part = structure.firstHTML {
                draft.bodyHTML = try await Self.decodedText(part, session: session, uid: reference.uid)
            }
            for part in structure.attachments {
                let raw = try await session.fetchSection(uid: reference.uid, section: part.section)
                draft.attachments.append(DraftAttachment(
                    filename: part.filename ?? part.section, mimeType: part.mimeType,
                    data: MailMIME.decodeTransfer(raw, encoding: part.encoding)))
            }
            return MailStoredDraft(id: messageID, draft: draft)
        }
    }

    public func deleteDraft(id: String) async throws {
        let reference = try IMAPMessageReference.decode(id)
        try await withIncoming { session in
            try await Self.removeMessage(reference, session: session)
        }
    }

    public func sendDraft(id: String) async throws {
        let stored = try await fetchDraft(messageID: id)
        try await send(stored.draft)
        try? await deleteDraft(id: id)
    }

    private static let summaryItems = ["UID", "FLAGS", "INTERNALDATE", "RFC822.SIZE", "ENVELOPE", "BODYSTRUCTURE",
                                        "BODY.PEEK[HEADER.FIELDS (REFERENCES)]"]
    private static let threadLimit = 20
    private static let inlineImageLimit = 2_097_152
    private static let inlineImageBudget = 8_388_608

    private static func decodedText(_ part: IMAPBodyPart, session: IMAPSession, uid: Int) async throws -> String {
        let raw = try await session.fetchSection(uid: uid, section: part.section)
        return MailMIME.string(from: MailMIME.decodeTransfer(raw, encoding: part.encoding), charset: part.charset)
    }

    private static func flagNames(_ flags: Set<MailFlag>) -> [String] {
        flags.sorted { $0.rawValue < $1.rawValue }.map {
            switch $0 {
            case .seen: "\\Seen"
            case .flagged: "\\Flagged"
            case .answered: "\\Answered"
            case .draft: "\\Draft"
            case .deleted: "\\Deleted"
            }
        }
    }

    private static func summary(_ entry: IMAPFetched, uid: Int, folder: String, uidValidity: Int) -> MailMessageSummary {
        let envelope = entry.envelope
        var flags: Set<MailFlag> = []
        for name in entry.flags {
            switch name {
            case "\\seen": flags.insert(.seen)
            case "\\flagged": flags.insert(.flagged)
            case "\\answered": flags.insert(.answered)
            case "\\draft": flags.insert(.draft)
            case "\\deleted": flags.insert(.deleted)
            default: break
            }
        }
        let id = IMAPMessageReference(folder: folder, uidValidity: uidValidity, uid: uid).encoded
        let references = entry.sections["HEADER.FIELDS (REFERENCES)"].map(MailMIME.parseHeaders)?
            .first { $0.name.lowercased() == "references" }?.value
            .split(separator: " ").first.map(String.init)
        let thread = references ?? envelope?.inReplyTo ?? envelope?.messageID ?? id
        let sender = envelope?.from.first ?? envelope?.sender.first
        let attachments = (entry.structure?.attachments ?? []).map {
            MailAttachmentInfo(id: $0.section, filename: $0.filename ?? $0.section, mimeType: $0.mimeType, sizeBytes: $0.size)
        }
        return MailMessageSummary(
            id: id, threadID: thread, subject: envelope?.subject ?? "", from: sender?.display ?? "",
            fromRaw: (envelope?.from ?? []).map(\.raw).joined(separator: ", "),
            toRaw: (envelope?.to ?? []).map(\.raw).joined(separator: ", "),
            ccRaw: (envelope?.cc ?? []).map(\.raw).joined(separator: ", "),
            snippet: "",
            receivedAt: entry.internalDate ?? envelope?.date.flatMap(MailMIME.parseMessageDate),
            flags: flags, folderIDs: [folder], attachmentCount: attachments.count,
            attachments: attachments, messageIDHeader: envelope?.messageID ?? "")
    }

    private func withIncoming<T: Sendable>(_ body: @Sendable (IMAPSession) async throws -> T) async throws -> T {
        guard account.incoming.isComplete else { throw MailTransportError.accountIncomplete("incoming") }
        let credential = try await credential(for: account.incoming)
        let session = try await IMAPSession.open(settings: account.incoming, opener: opener)
        do {
            try await session.authenticate(credential)
            let value = try await body(session)
            await session.logout()
            return value
        } catch {
            await session.close()
            throw error
        }
    }

    private func credential(for settings: MailServerSettings) async throws -> MailCredential {
        let user = settings.username.isEmpty ? account.address : settings.username
        switch account.authentication {
        case .password:
            if let password {
                let secret = try await password()
                guard secret.isEmpty == false else { throw MailTransportError.credentialsMissing }
                return .password(user: user, secret: secret)
            }
            let store = ServiceCredentialStore(.mail, fields: [CredentialField(account.id)])
            guard let secret = try store.load()?[account.id], secret.isEmpty == false else {
                throw MailTransportError.credentialsMissing
            }
            return .password(user: user, secret: secret)
        case .oauth:
            guard let accessToken else { throw MailTransportError.oauthUnavailable(account.provider) }
            let token: String
            do {
                token = try await accessToken()
            } catch {
                throw MailTransportError.oauthUnavailable(account.provider)
            }
            guard token.isEmpty == false else { throw MailTransportError.oauthUnavailable(account.provider) }
            return .oauth(user: user, token: token)
        }
    }
}
