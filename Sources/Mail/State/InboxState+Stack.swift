import Design
import Hub
import Shell

extension InboxState {
    var visibleStack: [CardRef] {
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

    public var stackOrder: [CardRef] {
        let visible = visibleStack
        guard let front = frontRef else { return visible }
        return visible.filter { $0 != front } + [front]
    }

    public var stackCount: Int { visibleStack.count }

    public func bring(_ ref: CardRef) {
        guard visibleStack.contains(ref) else { return }
        front = ref
        if case .message(let id) = ref { selectedMessage = id }
    }

    public func pin(_ id: String) {
        update(id) { $0.pinned = true }
    }

    public func card(_ id: String) -> OpenMessage? {
        cardIndex(id, in: selectedInlet).map { cards[$0] }
    }

    func cardIndex(_ id: String, in inlet: Inlet.ID?) -> Int? {
        cards.firstIndex { $0.id == id && $0.inlet == inlet }
    }

    func attach(_ ref: CardRef) {
        if !stack.contains(ref) { stack.append(ref) }
        front = ref
        opened += 1
    }

    func detach(_ ref: CardRef) {
        stack.removeAll { $0 == ref }
        if front == ref { front = stack.last }
    }

    func dropPreviews() {
        let inlet = selectedInlet
        let gone = cards.filter { $0.inlet == inlet && !$0.pinned }.map(\.id)
        cards.removeAll { $0.inlet == inlet && !$0.pinned }
        for id in gone { detach(.message(id)) }
    }

    public func openOverview(_ open: Bool) {
        overview.open = open
        if !open { overview.hot = nil }
    }

    public func setOverviewMode(_ mode: OverviewMode) {
        overview.mode = mode
    }

    public func setOverviewSize(_ size: OverviewSize) {
        overview.size = size
    }

    public func aimOverview(_ ref: CardRef?) {
        overview.hot = ref
    }

    func trimCards() {
        let inlet = selectedInlet
        while cards.filter({ $0.inlet == inlet }).count > Tokens.Count.stackMaxCards,
              let index = cards.firstIndex(where: { $0.inlet == inlet }) {
            detach(.message(cards.remove(at: index).id))
        }
    }

    public func commands(confirmDiscard: Bool, canFold: Bool, sendLabelled: Bool) -> CommandSet {
        var front: CommandEngine.Front?
        if case .message(let id) = frontRef, let card = card(id) {
            front = .message(hasCopy: !card.summary.ccRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else if case .draft(let id) = frontRef, let card = draft(id) {
            front = .draft(canSend: card.canSend)
        }
        return CommandEngine.commands(front: front, stackCount: stackCount, fanned: overview.open,
                                      hasFiles: mailbox.hasFiles, confirmDiscard: confirmDiscard, canFold: canFold,
                                      sendLabelled: sendLabelled)
    }
}
