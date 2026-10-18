import Foundation
import AlfaKit
import AlfaServices

struct CountingMailTransport: MailTransport {
    let base: any MailTransport
    let meter: CostMeter

    func listFolders() async throws -> [MailFolder] {
        meter.record()
        return try await base.listFolders()
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        meter.record()
        return try await base.listMessages(folderID: folderID, query: query, pageToken: pageToken, maxResults: maxResults)
    }

    func fetchBody(messageID: String) async throws -> MailMessageBody {
        meter.record()
        let body = try await base.fetchBody(messageID: messageID)
        meter.record(calls: 0, bytes: (body.text?.utf8.count ?? 0) + (body.html?.utf8.count ?? 0))
        return body
    }

    func send(_ draft: EmailDraft) async throws {
        meter.record()
        try await base.send(draft)
    }

    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {
        meter.record()
        try await base.setFlags(messageID: messageID, add: add, remove: remove)
    }

    func archive(messageID: String) async throws {
        meter.record()
        try await base.archive(messageID: messageID)
    }

    func move(messageID: String, toFolderID: String) async throws {
        meter.record()
        try await base.move(messageID: messageID, toFolderID: toFolderID)
    }

    func trash(messageID: String) async throws {
        meter.record()
        try await base.trash(messageID: messageID)
    }

    func markSpam(messageID: String) async throws {
        meter.record()
        try await base.markSpam(messageID: messageID)
    }

    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data {
        meter.record()
        let data = try await base.fetchAttachment(messageID: messageID, attachmentID: attachmentID)
        meter.record(calls: 0, bytes: data.count)
        return data
    }

    func fetchThread(messageID: String, threadID: String) async throws -> [MailMessageSummary] {
        meter.record()
        return try await base.fetchThread(messageID: messageID, threadID: threadID)
    }

    func saveDraft(_ draft: EmailDraft, replacing draftID: String?) async throws -> String {
        meter.record()
        return try await base.saveDraft(draft, replacing: draftID)
    }

    func fetchDraft(messageID: String) async throws -> MailStoredDraft {
        meter.record()
        return try await base.fetchDraft(messageID: messageID)
    }

    func deleteDraft(id: String) async throws {
        meter.record()
        try await base.deleteDraft(id: id)
    }

    func sendDraft(id: String) async throws {
        meter.record()
        try await base.sendDraft(id: id)
    }
}

extension PortCatalog {
    public static var withMail: PortCatalog {
        var catalog = PortCatalog.standard
        catalog.register(
            (any MailTransport).self,
            capability: .mail,
            wrap: { CountingMailTransport(base: $0, meter: $1) },
            sync: { transport, inlet in
                let folders = try await transport.listFolders()
                let records = folders.map {
                    MailboxRecord(id: inlet + "/" + $0.id, inlet: inlet, name: $0.name, role: $0.role.rawValue)
                }
                return SyncOutcome(deliveries: [.mailboxes: records])
            }
        )
        return catalog
    }
}

extension WriteOrder {
    public static func sendMail(inlet: Inlet.ID, draft: EmailDraft) -> WriteOrder {
        WriteOrder(inlet: inlet) { access, inlet in
            let transport = try access.port((any MailTransport).self, for: inlet)
            try await transport.send(draft)
        }
    }
}
