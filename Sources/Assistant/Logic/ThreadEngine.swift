import Foundation

enum ThreadEngine {
    static func turns(_ messages: [Message]) -> [ChatTurn] {
        messages.map(turn)
    }

    static func turn(_ message: Message) -> ChatTurn {
        let failure: String? = if case .failed(let reason) = message.status { reason } else { nil }
        var blocks = message.blocks.flatMap(blocks).filter { block in
            guard case .text(let value) = block else { return true }
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && value != failure
        }
        if message.role == .user {
            blocks = blocks.filter(\.isFile) + blocks.filter { $0.isFile == false }
        }
        return ChatTurn(id: message.id, kind: kind(message, failed: failure != nil), blocks: blocks)
    }

    static func kind(_ message: Message, failed: Bool) -> ChatTurn.Kind {
        if failed { return .failed }
        if message.status == .streaming { return .streaming }
        return message.role == .user ? .user : .assistant
    }

    static func blocks(_ block: ContentBlock) -> [TurnBlock] {
        switch block {
        case .text(let value): [.text(value)]
        case .toolUse, .toolResult: []
        case .toolActivity(let label, let isError): [.activity(label: label, failed: isError)]
        case .calendarLink(let url): [.draft(DraftSummary(kind: .calendar, title: url))]
        case .contactDraft(let draft): [.draft(DraftSummary(kind: .contact, title: draft.displayName, line: draft.organization ?? draft.email))]
        case .mailDraft(let draft): [.draft(DraftSummary(kind: .mail, title: draft.subject, line: draft.to))]
        case .driveFiles(let links): links.map { .file($0.name) }
        case .estimate(_, _, let minNet, let maxNet, _, _, _): [.estimate(minNet: minNet, maxNet: maxNet)]
        case .estimateBreakdown(_, let lines, _): [.breakdown(lines: lines.count)]
        case .airtableContactDraft(let draft): [.draft(DraftSummary(kind: .contact, title: draft.name, line: draft.organization ?? draft.email))]
        case .taskChangeDraft(let draft): [.draft(DraftSummary(kind: .task, title: draft.taskName, line: draft.projectNumber))]
        case .appointmentDraft(let draft): [.draft(DraftSummary(kind: .appointment, title: draft.title, line: draft.location))]
        case .cartDraft(let draft): [.draft(DraftSummary(kind: .cart, title: draft.label, line: draft.articleNumber))]
        case .fileDraft(let draft): [.draft(DraftSummary(kind: .file, title: draft.fileName, line: draft.projectNumber))]
        case .image(let ref), .document(let ref): [.file(ref.fileName)]
        case .unreadable: [.unreadable]
        }
    }

    static func attachments(_ message: Message) -> [AttachmentRef] {
        message.blocks.compactMap { block in
            switch block {
            case .image(let ref), .document(let ref): ref
            default: nil
            }
        }
    }
}
