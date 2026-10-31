import Foundation
import Hub

enum MirrorEngine {
    struct Plan: Equatable {
        var gone: Set<String>
        var unknown: [String]
        var known: [String]
    }

    enum Refusal: String, Equatable {
        case emptyListing
        case validityChanged
    }

    static let chunkSize = 200
    static let olderStep = 500
    static let pageSize = 100
    static let dropSize = 500
    static let landedSize = 50
    static let guardMinimum = 20
    static let reloadInterval = Duration.milliseconds(300)
    static let draftPreview = 600

    static func draftRow(_ id: String, _ draft: Draft, folder: String, account: String, thread: String, at date: Date) -> MessageSummary {
        let name = draft.from?.name ?? ""
        let address = draft.from?.address ?? account
        return MessageSummary(
            id: id, threadID: draft.threadID ?? thread, subject: draft.subject, from: name.isEmpty ? address : name,
            fromRaw: name.isEmpty ? address : name + " <" + address + ">", toRaw: draft.to ?? "", ccRaw: draft.cc ?? "",
            bccRaw: draft.bcc ?? "", snippet: String(PreviewEngine.text(draft.body).prefix(draftPreview)), receivedAt: date,
            flags: [.seen, .draft], folderIDs: [folder], attachmentCount: draft.attachments.count)
    }

    static func plan(stored: Set<String>, listed: [String]) -> Plan {
        let wanted = Set(listed)
        return Plan(gone: stored.subtracting(wanted), unknown: listed.filter { !stored.contains($0) },
                    known: listed.filter { stored.contains($0) })
    }

    static func chunks<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [items] }
        return stride(from: 0, to: items.count, by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
    }

    static func before(_ left: MessageSummary, _ right: MessageSummary) -> Bool {
        switch (left.receivedAt, right.receivedAt) {
        case (let a?, let b?) where a != b: a > b
        case (nil, _?): false
        case (_?, nil): true
        default: left.id > right.id
        }
    }

    static func sorted(_ messages: [MessageSummary]) -> [MessageSummary] {
        messages.sorted(by: before)
    }

    static func cutoff(_ range: MailboxRange, reach: Date?, now: Date) -> Date? {
        guard let base = range.cutoff(from: now) else { return nil }
        return max(reach.map { min($0, base) } ?? base, MailboxRange.earliest)
    }

    static func withStarred(_ folders: [Folder]) -> [Folder] {
        guard !folders.isEmpty, !folders.contains(where: { $0.role == .starred }) else { return folders }
        return folders + [Folder(id: Folder.starredID, name: "", role: .starred)]
    }

    static func ranges(_ transport: any MailTransportPort) -> [MailboxRange] {
        (transport as? any MirrorPort)?.ranges ?? []
    }

    static func refusal(plan: Plan, stored: Int, added: Int, validityChanged: Bool, narrowed: Bool,
                        confirmedEmpty: Bool) -> Refusal? {
        guard stored > 0, plan.gone.count == stored else { return nil }
        if validityChanged { return added == 0 ? .validityChanged : nil }
        guard added == 0, !narrowed, stored >= guardMinimum else { return nil }
        return confirmedEmpty ? nil : .emptyListing
    }

    static func newerThan(_ fresh: [MessageSummary], newest: Date?) -> Int {
        guard let newest else { return 0 }
        return fresh.filter { !$0.flags.contains(.seen) && ($0.receivedAt ?? .distantPast) > newest }.count
    }
}
