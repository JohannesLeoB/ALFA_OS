import Design
import Hub
import Mail
import SwiftUI

struct AccountDeck: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var shut = false
    @State private var ghost: (account: Inlet, level: Int)?
    @State private var lifted = false
    @State private var arrived = true
    @State private var flight: Task<Void, Never>?

    private var inbox: InboxState { session.inbox }

    private var settings: SettingsState { session.settings }

    private var current: Inlet? { inbox.selectedAccount }

    private var others: [Inlet] { inbox.accounts.filter { $0.id != inbox.selectedInlet } }

    private var open: Bool { !others.isEmpty && !shut }

    private var waiting: [Inlet] { others.filter { inbox.hasUnread($0.id) } }

    private var toggleHelp: String {
        if open { return appearance.string("mail.deck.hide") }
        let names = waiting.map { $0.mailboxName(settings.display($0.id)) }
        return names.isEmpty ? appearance.string("mail.deck.show") : appearance.format("mail.deck.showUnread", names.joined(separator: ", "))
    }

    var body: some View {
        let count = others.count
        ZStack(alignment: .top) {
            ForEach(Array(others.enumerated()), id: \.element.id) { level, account in
                AccountCard(account: account, display: settings.display(account.id), level: level, last: level == count - 1,
                            alert: inbox.hasUnread(account.id), named: arrived, choose: { settings.setDisplay($0, for: account.id) }) {
                    pick(account, level: level)
                }
                .frame(height: Deck.height(open ? level + 1 : 0))
                .animation(cardMotion(level, count: count), value: open)
                .zIndex(Double(count - level))
            }
            ComposeHead(account: current, display: current.map { settings.display($0.id) } ?? .ownName, named: arrived) { inbox.compose() }
                .background(appearance.color(\.lane))
                .lacquer(Deck.bottomRounded(open ? Tokens.Radius.card : 0), gloss: \.stackGlossFront, seam: \.stackSeamFront, drop: true, shown: open)
                .overlay(alignment: .topTrailing) {
                    if !others.isEmpty {
                        EnvelopeButton(open: open, alert: !open && !waiting.isEmpty, help: toggleHelp) { shut.toggle() }
                            .padding(CGFloat(Tokens.Spacing.step8))
                    }
                }
                .zIndex(Double(count + 1))
            if let ghost {
                MailboxGhost(account: ghost.account, display: settings.display(ghost.account.id), level: ghost.level, lifted: lifted)
                    .zIndex(Double(count + 2))
            }
        }
        .frame(height: Deck.height(open ? count : 0), alignment: .top)
        .frame(maxWidth: .infinity)
        .animation(appearance.ease(open ? Tokens.Transition.deckOpen : Tokens.Transition.deckClose), value: open)
        .onDisappear(perform: land)
    }

    private func pick(_ account: Inlet, level: Int) {
        guard !session.mailboxSwitching, ghost == nil else { return }
        session.switchMailbox(account.id, appearance: appearance)
        guard !appearance.still else { return }
        flight?.cancel()
        lifted = false
        arrived = false
        ghost = (account, level)
        flight = Task { @MainActor in
            try? await Task.sleep(for: .seconds(SheetValues.ghostStart))
            guard !Task.isCancelled else { return }
            lifted = true
            withAnimation(appearance.ease(Tokens.Duration.switchContentFade, Tokens.Easing.glassOut, delay: Tokens.Duration.switchFade)) { arrived = true }
            try? await Task.sleep(for: .seconds(SheetValues.ghostLife))
            guard !Task.isCancelled else { return }
            ghost = nil
            lifted = false
        }
    }

    private func land() {
        flight?.cancel()
        flight = nil
        ghost = nil
        lifted = false
        arrived = true
    }

    private func cardMotion(_ level: Int, count: Int) -> Animation? {
        let timing = open ? Tokens.Transition.deckOpen : Tokens.Transition.deckClose
        let stagger = open ? Double(level) * Tokens.Duration.deckOpenStagger : Double(count - 1 - level) * Tokens.Duration.deckCloseStagger
        return appearance.ease(timing.duration, timing.easing, delay: timing.delay + stagger)
    }
}
