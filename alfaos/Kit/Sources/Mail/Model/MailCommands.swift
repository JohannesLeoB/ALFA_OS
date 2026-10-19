import Foundation
import ShellCore

public enum MailHeadState: Equatable, Sendable {
    case empty
    case reading
    case draft
    case confirm
    case fanned
}

public struct MailCommands: Equatable, Sendable {
    public let state: MailHeadState
    public let main: [CommandSlot]
    public let tail: [CommandSlot]
    public let fan: [CommandSlot]
    public let fold: [CommandSlot]
    public let footLeft: [CommandSlot]
    public let footRight: [CommandSlot]
    public let staticMore: Bool

    public var hasFooter: Bool { !footLeft.isEmpty || !footRight.isEmpty }
}

extension MailModel {
    public func commands(confirmDiscard: Bool, canFold: Bool, formatOn: Bool, sendLabelled: Bool) -> MailCommands {
        let count = stackCount
        let fanned = overview.open
        var state = MailHeadState.empty
        var main: [CommandSlot] = []
        var tail: [CommandSlot] = []
        var left: [CommandSlot] = []
        var right: [CommandSlot] = []
        if fanned {
            state = .fanned
        } else if case .message(let id) = frontRef, let card = card(id) {
            state = .reading
            let hasCopy = !card.summary.ccRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            main = [
                CommandSlot(id: "reply", action: .reply, priority: 1),
                CommandSlot(id: "replyAll", action: .replyAll, priority: 4, off: !hasCopy),
                CommandSlot(id: "forward", action: .forward, priority: 2),
                .separator,
                CommandSlot(id: "archive", action: .archive, priority: 5),
                CommandSlot(id: "trash", action: .trash, priority: 3, signal: true)
            ]
            left = [
                CommandSlot(id: "print", action: .print, priority: 1),
                CommandSlot(id: "pdf", action: .pdf, priority: 2),
                CommandSlot(id: "toProject", action: .toProject, priority: 3)
            ]
            right = [CommandSlot(id: "footMore", action: .more)]
        } else if case .draft(let id) = frontRef, let card = draft(id) {
            if confirmDiscard {
                state = .confirm
                tail = [CommandSlot(id: "discardPill", action: .discardDraft, kind: .pill, cost: SheetValues.commandConfirmCost)]
            } else {
                state = .draft
                main = [
                    CommandSlot(id: "saveDraft", action: .saveDraft, priority: 5),
                    CommandSlot(id: "discardDraft", action: .discardDraft, priority: 2, signal: true)
                ]
                left = [
                    CommandSlot(id: "attachFile", action: .attachFile, priority: 1),
                    CommandSlot(id: "fromProject", action: .fromProject, priority: 4, off: true),
                    CommandSlot(id: "format", action: .format, priority: 3, accent: formatOn)
                ]
                right = [
                    CommandSlot(id: "footMore", action: .more),
                    CommandSlot(id: "send", action: .send, cost: sendLabelled ? SheetValues.commandSendCost : SheetValues.commandIconCost,
                                off: !card.canSend, accent: true)
                ]
            }
        }
        let fanSlots = (count > 0 || fanned) && state != .confirm
            ? [CommandSlot(id: "overview", action: fanned ? .backToStack : .overview, accent: fanned)] : []
        let foldSlots = canFold && state != .confirm ? [CommandSlot(id: "fold", action: .foldColumn)] : []
        return MailCommands(state: state, main: main, tail: tail, fan: fanSlots, fold: foldSlots, footLeft: left,
                            footRight: fanned ? [] : right, staticMore: false)
    }
}
