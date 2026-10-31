import Foundation
import GRDB
import Hub

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
