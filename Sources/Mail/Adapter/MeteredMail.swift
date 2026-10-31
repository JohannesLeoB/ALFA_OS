import Foundation
import Hub

struct MeteredMail: MailTransportPort, PurgePort, SourcePort, MirrorPort, EverywhereSearchPort, UnseenCountPort, LabelPort, SenderPort, SentCopyPort, InboxOnlyPort, ServerCopyPort, SendLimitPort {
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

    func archive(messageID: String, folderID: String?) async throws {
        meter.record()
        try await base.archive(messageID: messageID, folderID: folderID)
    }

    func move(messageID: String, toFolderID: String) async throws {
        meter.record()
        try await base.move(messageID: messageID, toFolderID: toFolderID)
    }

    func trash(messageID: String, folderID: String?) async throws {
        meter.record()
        try await base.trash(messageID: messageID, folderID: folderID)
    }

    func markSpam(messageID: String, folderID: String?) async throws {
        meter.record()
        try await base.markSpam(messageID: messageID, folderID: folderID)
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

    func saveDraft(_ draft: Draft, replacing draftID: String?, into folderID: String?) async throws -> SavedDraft {
        meter.record()
        return try await base.saveDraft(draft, replacing: draftID, into: folderID)
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

    func wasSent(messageID: String, in folderID: String?) async throws -> Bool {
        meter.record()
        return try await base.wasSent(messageID: messageID, in: folderID)
    }

    var filesSentCopy: Bool { (base as? any SentCopyPort)?.filesSentCopy ?? false }

    func fileSent(_ draft: Draft, into folderID: String?) async throws {
        guard let base = base as? any SentCopyPort else { throw MailFailure.unsupportedCapability("sentCopy") }
        meter.record()
        try await base.fileSent(draft, into: folderID)
    }

    var usesLabels: Bool { (base as? any LabelPort)?.usesLabels ?? false }

    var inboxOnly: Bool { (base as? any InboxOnlyPort)?.inboxOnly ?? false }

    func sendLimit() async throws -> Int? {
        guard let base = base as? any SendLimitPort else { return nil }
        meter.record()
        return try await base.sendLimit()
    }

    func expire(_ policy: ServerCopy, now: Date) async throws {
        guard let base = base as? any ServerCopyPort else { return }
        meter.record()
        try await base.expire(policy, now: now)
    }

    var offersSource: Bool { (base as? any SourcePort)?.offersSource ?? false }

    func fetchSource(messageID: String) async throws -> Data {
        guard let base = base as? any SourcePort else { throw MailFailure.unsupportedCapability("source") }
        meter.record()
        return try await base.fetchSource(messageID: messageID)
    }

    var ranges: [MailboxRange] { (base as? any MirrorPort)?.ranges ?? [] }
    var fillsPreviews: Bool { (base as? any MirrorPort)?.fillsPreviews ?? false }

    func startCursor() async throws -> String? {
        guard let base = base as? any MirrorPort else { throw MailFailure.unsupportedCapability("mirror") }
        meter.record()
        return try await base.startCursor()
    }

    func listIDs(folderID: String, since: Date?, limit: Int?) async throws -> MirrorListing {
        guard let base = base as? any MirrorPort else { throw MailFailure.unsupportedCapability("mirror") }
        meter.record()
        return try await base.listIDs(folderID: folderID, since: since, limit: limit)
    }

    func fetchSummaries(folderID: String, ids: [String]) async throws -> [MessageSummary] {
        guard let base = base as? any MirrorPort else { throw MailFailure.unsupportedCapability("mirror") }
        meter.record(calls: ids.count)
        return try await base.fetchSummaries(folderID: folderID, ids: ids)
    }

    func refreshFlags(folderID: String, known: [String], cursor: String?) async throws -> FlagRefresh {
        guard let base = base as? any MirrorPort else { throw MailFailure.unsupportedCapability("mirror") }
        meter.record()
        return try await base.refreshFlags(folderID: folderID, known: known, cursor: cursor)
    }

    func unseen(folderID: String) async throws -> FolderCount? {
        guard let base = base as? any UnseenCountPort else { return nil }
        meter.record()
        return try await base.unseen(folderID: folderID)
    }

    func offersEverywhere(in folders: [Folder]) -> Bool {
        (base as? any EverywhereSearchPort)?.offersEverywhere(in: folders) ?? false
    }

    func searchEverywhere(query: String, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        guard let base = base as? any EverywhereSearchPort else { throw MailFailure.unsupportedCapability("search") }
        meter.record()
        return try await base.searchEverywhere(query: query, pageToken: pageToken, maxResults: maxResults)
    }

    func senders() async throws -> [Participant] {
        guard let base = base as? any SenderPort else { throw MailFailure.unsupportedCapability("senders") }
        meter.record()
        return try await base.senders()
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
            sync: { port, inlet, _ in
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
