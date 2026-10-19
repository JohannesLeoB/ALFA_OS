import Foundation
import ShellCore
import struct AlfaServices.MailMessageSummary

extension MailModel {
    public var visibleStack: [CardRef] {
        stack.filter { ref in
            if case .draft(let id) = ref, draft(id)?.state == .sent { return false }
            return true
        }
    }

    public var frontRef: CardRef? {
        let visible = visibleStack
        if let front, visible.contains(front) { return front }
        return visible.last
    }

    public var stackEmpty: Bool { visibleStack.isEmpty }

    public var stackOrder: [CardRef] {
        let visible = visibleStack
        guard let front = frontRef else { return visible }
        return visible.filter { $0 != front } + [front]
    }

    public func bring(_ ref: CardRef) {
        guard visibleStack.contains(ref) else { return }
        front = ref
        if case .message(let id) = ref { selectedMessage = id }
    }

    public func pin(_ id: String) {
        update(id) { $0.pinned = true }
    }

    public func card(_ id: String) -> ReadingCard? {
        cards.first { $0.id == id }
    }

    func attach(_ ref: CardRef) {
        if !stack.contains(ref) { stack.append(ref) }
        front = ref
    }

    func detach(_ ref: CardRef) {
        stack.removeAll { $0 == ref }
        if front == ref { front = stack.last }
    }

    func dropPreviews() {
        let gone = cards.filter { !$0.pinned }.map(\.id)
        cards.removeAll { !$0.pinned }
        for id in gone { detach(.message(id)) }
    }

    public func openOverview(_ open: Bool) {
        overview.open = open
        if !open { overview.hot = nil }
    }

    public func setOverviewMode(_ mode: MailOverviewMode) {
        overview.mode = mode
    }

    public func setOverviewSize(_ size: OverviewSize) {
        overview.size = size
    }

    public func aimOverview(_ ref: CardRef?) {
        overview.hot = ref
    }

    public var overviewMessages: [MailMessageSummary] {
        rows.map(\.summary)
    }

    public var stackCount: Int { visibleStack.count }
}
