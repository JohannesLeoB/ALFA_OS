import Foundation
import ShellCore

public enum MailHeadState: Equatable, Sendable {
    case empty
    case reading
    case draft
    case confirm
    case fanned
}

public typealias MailSlot = CommandSlot<MailAction>

public struct MailCommands: Equatable, Sendable {
    public let state: MailHeadState
    public let main: [MailSlot]
    public let tail: [MailSlot]
    public let fan: [MailSlot]
    public let fold: [MailSlot]
    public let footLeft: [MailSlot]
    public let footRight: [MailSlot]
    public let staticMore: Bool

    public var hasFooter: Bool { !footLeft.isEmpty || !footRight.isEmpty }
}

extension MailModel {
    public func commands(confirmDiscard: Bool, canFold: Bool, formatOn: Bool, sendLabelled: Bool) -> MailCommands {
        let count = stackCount
        let fanned = overview.open
        var state = MailHeadState.empty
        var main: [MailSlot] = []
        var tail: [MailSlot] = []
        var left: [MailSlot] = []
        var right: [MailSlot] = []
        if fanned {
            state = .fanned
        } else if case .message(let id) = frontRef, let card = card(id) {
            state = .reading
            let hasCopy = !card.summary.ccRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            main = [
                MailSlot(id: "reply", action: .reply, priority: 1),
                MailSlot(id: "replyAll", action: .replyAll, priority: 4, off: !hasCopy),
                MailSlot(id: "forward", action: .forward, priority: 2),
                .separator,
                MailSlot(id: "archive", action: .archive, priority: 5),
                MailSlot(id: "trash", action: .trash, priority: 3, signal: true)
            ]
            left = [
                MailSlot(id: "print", action: .print, priority: 1),
                MailSlot(id: "pdf", action: .pdf, priority: 2),
                MailSlot(id: "toProject", action: .toProject, priority: 3, off: !engine.hasFiles)
            ]
            right = [MailSlot.more]
        } else if case .draft(let id) = frontRef, let card = draft(id) {
            if confirmDiscard {
                state = .confirm
                tail = [MailSlot(id: "discardPill", action: .discardDraft, kind: .pill, cost: SheetValues.commandConfirmCost)]
            } else {
                state = .draft
                main = [
                    MailSlot(id: "saveDraft", action: .saveDraft, priority: 5),
                    MailSlot(id: "discardDraft", action: .discardDraft, priority: 2, signal: true)
                ]
                left = [
                    MailSlot(id: "attachFile", action: .attachFile, priority: 1),
                    MailSlot(id: "fromProject", action: .fromProject, priority: 4, off: !engine.hasFiles),
                    MailSlot(id: "format", action: .format, priority: 3, accent: formatOn)
                ]
                right = [
                    MailSlot.more,
                    MailSlot(id: "send", action: .send, cost: sendLabelled ? SheetValues.commandSendCost : SheetValues.commandIconCost,
                                off: !card.canSend, accent: true)
                ]
            }
        }
        let fanSlots = (count > 0 || fanned) && state != .confirm
            ? [MailSlot(id: "overview", action: fanned ? .backToStack : .overview, accent: fanned)] : []
        let foldSlots = canFold && state != .confirm ? [MailSlot(id: "fold", action: .foldColumn)] : []
        return MailCommands(state: state, main: main, tail: tail, fan: fanSlots, fold: foldSlots, footLeft: left,
                            footRight: fanned ? [] : right, staticMore: false)
    }
}
