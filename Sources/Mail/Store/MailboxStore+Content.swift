import Foundation
import GRDB
import Hub
import Storage

struct AttachmentCandidate: Sendable {
    let id: String
    let receivedAt: Date?
    let known: [AttachmentInfo]
}

extension MailboxStore {
    static let storeFailureLimit = 3

    public func settleAttachments() async {
        guard attachments.settings().attachments else {
            attachments.removeAll()
            return
        }
        attachments.enforce()
        for account in accounts { startStoring(account.id) }
    }

    public func moveAttachments(to folder: Data?, commit: @MainActor () -> Void) async -> Bool {
        await attachments.move(to: folder, commit: commit)
    }

    func startStoring(_ inlet: Inlet.ID) {
        guard attachments.enabled, !storing.contains(inlet) else { return }
        Task { await storeAttachments(inlet) }
    }

    func storeAttachments(_ inlet: Inlet.ID) async {
        guard attachments.enabled, !storing.contains(inlet), let transport = try? transport(inlet) else { return }
        storing.insert(inlet)
        defer { storing.remove(inlet) }
        var failures = 0
        for mail in attachmentCandidates(inlet) {
            guard !Task.isCancelled, attachments.enabled else { return }
            let have = attachments.stored(inlet, message: mail.id)
            var known = mail.known
            if known.isEmpty {
                guard let opened = try? await body(inlet, messageID: mail.id) else {
                    failures += 1
                    if failures >= Self.storeFailureLimit { return }
                    continue
                }
                known = opened.attachments
            }
            for info in known where !have.contains(info.id) {
                guard !Task.isCancelled, attachments.admits(size: info.sizeBytes, receivedAt: mail.receivedAt) else { return }
                guard let data = try? await transport.fetchAttachment(messageID: mail.id, attachmentID: info.id) else {
                    failures += 1
                    if failures >= Self.storeFailureLimit { return }
                    continue
                }
                guard attachmentMail(inlet, mail.id) != nil else { break }
                await attachments.store(data, inlet: inlet, message: mail.id, attachment: info.id, filename: info.filename,
                                        receivedAt: mail.receivedAt)
            }
        }
    }

    func keepAttachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String, _ data: Data) async {
        guard attachments.enabled, let mail = attachmentMail(inlet, messageID) else { return }
        let listed = mail.known + (keptBody(inlet, messageID: messageID)?.attachments ?? [])
        let name = listed.first { $0.id == attachmentID }?.filename ?? AttachmentFileEngine.fallbackName
        await attachments.store(data, inlet: inlet, message: messageID, attachment: attachmentID, filename: name,
                                receivedAt: mail.receivedAt)
    }

    func attachmentMail(_ inlet: Inlet.ID, _ messageID: String) -> AttachmentCandidate? {
        let found = try? database.read { db in
            try Row.fetchOne(db, sql: "SELECT id, receivedAt, attachments FROM mail_message WHERE inlet = ? AND id = ? LIMIT 1",
                             arguments: [inlet, messageID]).map(Self.candidate)
        }
        return found.flatMap { $0 }
    }

    func attachmentCandidates(_ inlet: Inlet.ID) -> [AttachmentCandidate] {
        let rows = try? database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, MAX(receivedAt) AS receivedAt, attachments FROM mail_message
                WHERE inlet = ? AND attachmentCount > 0 GROUP BY id ORDER BY receivedAt DESC, id DESC
                """, arguments: [inlet]).map(Self.candidate)
        }
        return rows ?? []
    }

    nonisolated private static func candidate(_ row: Row) -> AttachmentCandidate {
        let received: Double? = row["receivedAt"]
        let stored: Data? = row["attachments"]
        let known = stored.flatMap { try? JSONDecoder().decode([AttachmentInfo].self, from: $0) } ?? []
        return AttachmentCandidate(id: row["id"], receivedAt: received.map { Date(timeIntervalSince1970: $0) }, known: known)
    }
}

extension MailboxStore {
    func keptBody(_ inlet: Inlet.ID, messageID: String) -> MessageBody? {
        let found = try? database.read { db -> (String?, String?, Data, Data, Data?)? in
            guard let row = try Row.fetchOne(db, sql: "SELECT text, html, images, attachments, unsubscribe FROM mail_body WHERE inlet = ? AND id = ?",
                                             arguments: [inlet, messageID]) else { return nil }
            return (row["text"], row["html"], row["images"], row["attachments"], row["unsubscribe"])
        }
        guard let (text, html, images, attachments, list) = found.flatMap({ $0 }) else { return nil }
        guard let decodedImages = try? JSONDecoder().decode([String: String].self, from: images),
              let decodedAttachments = try? JSONDecoder().decode([AttachmentInfo].self, from: attachments) else { return nil }
        let unsubscribe = list.flatMap { try? JSONDecoder().decode(ListUnsubscribe.self, from: $0) }
        return MessageBody(text: text, html: html, inlineImages: decodedImages, attachments: decodedAttachments, unsubscribe: unsubscribe)
    }

    func keepBody(_ inlet: Inlet.ID, messageID: String, _ body: MessageBody) {
        guard body.text != nil || body.html != nil,
              let images = try? JSONEncoder().encode(body.inlineImages),
              let attachments = try? JSONEncoder().encode(body.attachments) else { return }
        let list = body.unsubscribe.flatMap { try? JSONEncoder().encode($0) }
        try? database.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO mail_body (inlet, id, text, html, images, attachments, unsubscribe) VALUES (?, ?, ?, ?, ?, ?, ?)",
                           arguments: [inlet, messageID, body.text, body.html, images, attachments, list])
        }
    }

    nonisolated static func dropOrphanBodies(_ db: Database, inlet: Inlet.ID, ids: [String]? = nil) throws {
        let orphan = "inlet = ? AND NOT EXISTS (SELECT 1 FROM mail_message WHERE mail_message.inlet = mail_body.inlet AND mail_message.id = mail_body.id)"
        guard let ids else {
            try db.execute(sql: "DELETE FROM mail_body WHERE " + orphan, arguments: [inlet])
            return
        }
        for chunk in MirrorEngine.chunks(ids, size: MirrorEngine.dropSize) {
            let marks = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            try db.execute(sql: "DELETE FROM mail_body WHERE id IN (\(marks)) AND " + orphan,
                           arguments: StatementArguments(chunk + [inlet]))
        }
    }
}

extension MailboxStore {
    static let sendersKey = "senders"

    public func sender(_ inlet: Inlet.ID) -> Participant {
        knownSenders(inlet).first ?? Participant(name: names(inlet).chosen, address: accountAddress(inlet))
    }

    public func knownSenders(_ inlet: Inlet.ID) -> [Participant] {
        let address = accountAddress(inlet)
        guard !address.isEmpty else { return [] }
        let own = names(inlet)
        return SenderEngine.merged(account: address, chosen: own.chosen, profile: own.profile, stored: storedSenders(inlet))
    }

    public func senders(_ inlet: Inlet.ID) async -> [Participant] {
        if let port = (try? transport(inlet)) as? any SenderPort, let found = try? await port.senders() {
            storeSenders(inlet, found)
        }
        return knownSenders(inlet)
    }

    func warmSenders(_ inlet: Inlet.ID) async {
        guard cursor(inlet, Self.sendersKey) == nil else { return }
        _ = await senders(inlet)
    }

    private func accountAddress(_ inlet: Inlet.ID) -> String {
        accounts.first { $0.id == inlet }?.account ?? ""
    }

    private func storedSenders(_ inlet: Inlet.ID) -> [Participant] {
        guard let text = cursor(inlet, Self.sendersKey), let data = text.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Participant].self, from: data)) ?? []
    }

    private func storeSenders(_ inlet: Inlet.ID, _ senders: [Participant]) {
        guard let data = try? JSONEncoder().encode(senders), let text = String(data: data, encoding: .utf8) else { return }
        try? setCursor(inlet, Self.sendersKey, text)
    }
}

extension MailboxStore {
    nonisolated private static let starredSelect = """
        SELECT * FROM mail_message WHERE inlet = ?1 AND flags LIKE '%flagged%'
        AND folder NOT IN (SELECT id FROM mail_folder WHERE inlet = ?1 AND role IN ('trash', 'spam'))
        """

    nonisolated static func starredMessages(_ database: SQLiteStore, inlet: Inlet.ID) -> [MessageSummary] {
        (try? database.read { db in
            try Row.fetchAll(db, sql: starredSelect + " ORDER BY receivedAt DESC, id DESC", arguments: [inlet]).map(summary)
        }) ?? []
    }

    func starredMatches(_ inlet: Inlet.ID, query: String) -> [MessageSummary] {
        let pattern = "%" + query.replacingOccurrences(of: "%", with: "") + "%"
        let rows = try? database.read { db in
            try Row.fetchAll(db, sql: Self.starredSelect + """
                 AND (subject LIKE ?2 OR sender LIKE ?2 OR fromRaw LIKE ?2 OR toRaw LIKE ?2 OR ccRaw LIKE ?2 OR snippet LIKE ?2)
                 ORDER BY receivedAt DESC, id DESC
                """, arguments: [inlet, pattern]).map(Self.summary)
        }
        return rows ?? []
    }

    func announceChange(_ inlet: Inlet.ID, _ folder: String) {
        eventBus.emit(.messagesChanged(inlet, folder: folder))
        guard folder != Folder.starredID, folders(inlet).contains(where: { $0.id == Folder.starredID }) else { return }
        eventBus.emit(.messagesChanged(inlet, folder: Folder.starredID))
    }
}
