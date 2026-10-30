import Shell

enum CommandEngine {
    enum Front: Equatable, Sendable {
        case message(hasCopy: Bool)
        case draft(canSend: Bool)
    }

    static func commands(front: Front?, stackCount: Int, fanned: Bool, hasFiles: Bool, confirmDiscard: Bool,
                                canFold: Bool, sendLabelled: Bool, formatting: Bool = false, folders: Bool = true) -> CommandSet {
        var state = HeadState.empty
        var main: [Slot] = []
        var tail: [Slot] = []
        var left: [Slot] = []
        var right: [Slot] = []
        if fanned {
            state = .fanned
        } else if case .message(let hasCopy) = front {
            state = .reading
            main = [
                Slot(id: "reply", action: .reply, priority: 1),
                Slot(id: "replyAll", action: .replyAll, priority: 4, off: !hasCopy),
                Slot(id: "forward", action: .forward, priority: 2),
                .separator
            ] + (folders ? [Slot(id: "archive", action: .archive, priority: 5)] : []) + [
                Slot(id: "trash", action: .trash, priority: 3, signal: true)
            ]
            left = [
                Slot(id: "print", action: .print, priority: 1),
                Slot(id: "pdf", action: .pdf, priority: 2),
                Slot(id: "toProject", action: .toProject, priority: 3, off: !hasFiles)
            ]
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
                left = [
                    Slot(id: "attachFile", action: .attachFile, priority: 1),
                    Slot(id: "fromProject", action: .fromProject, priority: 4, off: !hasFiles),
                    Slot(id: "format", action: .format, priority: 3, accent: formatting)
                ]
                right = [
                    Slot.more,
                    Slot(id: "send", action: .send,
                         cost: sendLabelled ? ShellValues.commandSendCost : ShellValues.commandIconCost,
                         off: !canSend, accent: true)
                ]
            }
        }
        let fanSlots = (stackCount > 0 || fanned) && state != .confirm
            ? [Slot(id: "overview", action: fanned ? .backToStack : .overview, accent: fanned)] : []
        let foldSlots = canFold && state != .confirm ? [Slot(id: "fold", action: .foldColumn)] : []
        return CommandSet(state: state, main: main, tail: tail, fan: fanSlots, fold: foldSlots, footLeft: left,
                          footRight: fanned ? [] : right)
    }
}

enum HeadState: Equatable, Sendable {
    case empty
    case reading
    case draft
    case confirm
    case fanned
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
