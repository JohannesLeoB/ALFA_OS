import Foundation

struct POPEntry: Equatable, Sendable {
    var uid: String
    var folder: String
    var head: Data
    var snippet: String
    var attachments: [AttachmentInfo]
    var seen: Bool
    var flagged: Bool
    var hidden: Bool
    var onServer: Bool
    var receivedAt: Date
    var fetchedAt: Date

    var flags: Set<Flag> {
        var flags: Set<Flag> = []
        if seen { flags.insert(.seen) }
        if flagged { flags.insert(.flagged) }
        return flags
    }

    func summary() -> MessageSummary {
        let parsed = RawMessageEngine.parse(head)
        var summary = RawMessageEngine.summary(parsed, id: uid, folder: folder, flags: flags, received: receivedAt)
        summary.snippet = snippet
        summary.attachments = attachments
        summary.attachmentCount = attachments.count
        return summary
    }
}
