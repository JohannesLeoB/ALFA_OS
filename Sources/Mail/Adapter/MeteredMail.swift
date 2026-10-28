import Foundation
import Hub

struct MeteredMail: MailTransportPort, PurgePort, SourcePort {
    let base: any MailTransportPort
    let meter: CostMeter

    func listFolders() async throws -> [Folder] {
        meter.record()
        return try await base.listFolders()
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        meter.record()
        return try await base.listMessages(folderID: folderID, query: query, pageToken: pageToken, maxResults: maxResults)
    }

    func fetchBody(messageID: String) async throws -> MessageBody {
        meter.record()
        let body = try await base.fetchBody(messageID: messageID)
        meter.record(calls: 0, bytes: (body.text?.utf8.count ?? 0) + (body.html?.utf8.count ?? 0))
        return body
    }

    func send(_ draft: Draft) async throws {
        meter.record()
        try await base.send(draft)
    }

    func setFlags(messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws {
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

    func fetchThread(messageID: String, threadID: String) async throws -> [MessageSummary] {
        meter.record()
        return try await base.fetchThread(messageID: messageID, threadID: threadID)
    }

    func saveDraft(_ draft: Draft, replacing draftID: String?) async throws -> String {
        meter.record()
        return try await base.saveDraft(draft, replacing: draftID)
    }

    func fetchDraft(messageID: String) async throws -> StoredDraft {
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

    func wasSent(messageID: String) async throws -> Bool {
        meter.record()
        return try await base.wasSent(messageID: messageID)
    }

    var offersSource: Bool { (base as? any SourcePort)?.offersSource ?? false }

    func fetchSource(messageID: String) async throws -> Data {
        guard let base = base as? any SourcePort else { throw MailFailure.unsupportedCapability("source") }
        meter.record()
        return try await base.fetchSource(messageID: messageID)
    }

    func supportsPurge() async throws -> Bool {
        guard let base = base as? any PurgePort else { return false }
        meter.record()
        return try await base.supportsPurge()
    }

    func purge(messageID: String) async throws {
        guard let base = base as? any PurgePort else { throw MailFailure.unsupportedCapability("purge") }
        meter.record()
        try await base.purge(messageID: messageID)
    }
}

extension PortRegistry {
    public func withMail() -> PortRegistry {
        var registry = self
        registry.register(
            (any MailTransportPort).self,
            capability: .mail,
            wrap: { MeteredMail(base: $0, meter: $1) },
            sync: { port, inlet in
                let folders = try await port.listFolders()
                let records = folders.map {
                    Mailbox(id: inlet + "/" + $0.id, inlet: inlet, name: $0.name, role: $0.role.rawValue)
                }
                return SyncOutcome(deliveries: [.mailboxes: records])
            }
        )
        return registry
    }
}
