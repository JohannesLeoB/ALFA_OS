import Foundation
import Shell

enum CommandEngine {
    enum Front: Equatable, Sendable {
        case message(hasCopy: Bool)
        case draft(canSend: Bool)
    }

    static func commands(front: Front?, stackCount: Int, fanned: Bool, hasFiles: Bool, confirmDiscard: Bool,
                                canFold: Bool, sendLabelled: Bool, formatting: Bool = false, folders: Bool = true,
                                trashes: Bool = true, archives: Bool = true) -> CommandSet {
        var state = HeadState.empty
        var main: [Slot] = []
        var tail: [Slot] = []
        var left: [Slot] = []
        var right: [Slot] = []
        if fanned {
            state = .fanned
        } else if case .message(let hasCopy) = front {
            state = .reading
            let bin = trashes ? [Slot(id: "trash", action: .trash, priority: 3, signal: true)] : []
            let moves = (folders && archives ? [Slot(id: "archive", action: .archive, priority: 5)] : []) + bin
            main = [
                Slot(id: "reply", action: .reply, priority: 1),
                Slot(id: "replyAll", action: .replyAll, priority: 4, off: !hasCopy),
                Slot(id: "forward", action: .forward, priority: 2)
            ] + (moves.isEmpty ? [] : [Slot.separator] + moves)
            left = [
                Slot(id: "print", action: .print, priority: 1),
                Slot(id: "pdf", action: .pdf, priority: 2)
            ] + (hasFiles ? [Slot(id: "toProject", action: .toProject, priority: 3)] : [])
            right = [Slot.more]
        } else if case .draft(let canSend) = front {
            if confirmDiscard {
                state = .confirm
                tail = [Slot(id: "discardPill", action: .discardDraft, kind: .pill, cost: ShellValues.commandConfirmCost)]
            } else {
                state = .draft
                main = [
                    Slot(id: "saveDraft", action: .saveDraft, priority: 5),
                    Slot(id: "discardDraft", action: .discardDraft, priority: 2, signal: true)
                ]
                left = [Slot(id: "attachFile", action: .attachFile, priority: 1)]
                    + (hasFiles ? [Slot(id: "fromProject", action: .fromProject, priority: 4)] : [])
                    + [Slot(id: "format", action: .format, priority: 3, accent: formatting)]
                right = [
                    Slot.more,
                    Slot(id: "send", action: .send,
                         cost: sendLabelled ? ShellValues.commandSendCost : ShellValues.commandIconCost,
                         off: !canSend, accent: true)
                ]
            }
        }
        let fanSlots = (stackCount > 0 || fanned) && state != .confirm
            ? [Slot(id: "overview", action: fanned ? .backToStack : .overview)] : []
        let foldSlots = canFold && state != .confirm ? [Slot(id: "fold", action: .foldColumn)] : []
        return CommandSet(state: state, main: main, tail: tail, fan: fanSlots, fold: foldSlots, footLeft: left,
                          footRight: fanned ? [] : right)
    }
}

public typealias Slot = CommandSlot<Action>

public struct CommandSet: Equatable, Sendable {
    let state: HeadState
    public let main: [Slot]
    public let tail: [Slot]
    public let fan: [Slot]
    public let fold: [Slot]
    public let footLeft: [Slot]
    public let footRight: [Slot]

    public var hasFooter: Bool { !footLeft.isEmpty || !footRight.isEmpty }
}

public enum SlotEffect: Equatable, Sendable {
    case openOverview
    case closeOverview
    case fold
    case saveDraft(UUID)
    case discardDraft(UUID)
    case send(UUID)
    case attachFile(UUID)
    case toggleFormat
    case message(Action, String)
}

public enum SlotRouter {
    public static func route(_ action: Action, front: CardRef?) -> SlotEffect? {
        switch (action, front) {
        case (.overview, _): return .openOverview
        case (.backToStack, _): return .closeOverview
        case (.foldColumn, _): return .fold
        case (.saveDraft, .draft(let id)): return .saveDraft(id)
        case (.discardDraft, .draft(let id)): return .discardDraft(id)
        case (.send, .draft(let id)): return .send(id)
        case (.attachFile, .draft(let id)): return .attachFile(id)
        case (.format, .draft): return .toggleFormat
        case (_, .message(let id)): return .message(action, id)
        default: return nil
        }
    }
}

public enum MenuEngine {
    private static let printableExtensions: Set<String> = ["pdf", "png", "jpg", "jpeg", "gif", "heic", "txt"]

    public static func row(unread: Bool, draft: Bool, folders: Bool = true, trashes: Bool = true, archives: Bool = true) -> [MenuLine] {
        if draft { return [.item(.openDraft)] }
        let bin: [MenuLine] = trashes ? [.separator, .item(.trash)] : []
        return [.item(.reply), .item(.forward), .separator] + (folders && archives ? [.item(.archive)] : [])
            + [.item(unread ? .markRead : .markUnread)] + (folders ? [.item(.move)] : []) + bin
    }

    public static func readingMore(starred: Bool, original: Bool, unread: Bool = false, folders: Bool = true, spam: Bool = true) -> [MenuLine] {
        let marks: [MenuLine] = [.item(starred ? .unstar : .star), .item(unread ? .markRead : .markUnread)] + (folders ? [.item(.move)] : [])
        let more: [MenuLine] = (original ? [.item(.original)] : []) + (folders && spam ? [.item(.spam)] : [])
        return more.isEmpty ? marks : marks + [.separator] + more
    }

    public static func draftMore(receipt: Bool) -> [MenuLine] {
        [.item(.laterSend), .item(.receipt, checked: receipt), .separator, .item(.print)]
    }

    public static func person(address: String, contact: Bool) -> [MenuLine] {
        [.head(address), .item(.copyAddress), .item(.writeMail), .item(contact ? .editContact : .saveContact)]
    }

    public static func attachment(name: String, project: Bool = true) -> [MenuLine] {
        let printable = printableExtensions.contains(name.split(separator: ".").last.map { $0.lowercased() } ?? "")
        return [.item(.preview)] + (printable ? [.item(.print), .item(.pdf)] : []) + [.separator] + (project ? [.item(.otherProject)] : []) + [.item(.saveAs)]
    }
}
