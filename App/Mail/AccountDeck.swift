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

    private var inbox: InboxState { session.inbox }

    private var current: Inlet? { inbox.accounts.first { $0.id == inbox.selectedInlet } }

    private var others: [Inlet] { inbox.accounts.filter { $0.id != inbox.selectedInlet } }

    private var open: Bool { !others.isEmpty && !shut }

    private var waiting: [Inlet] { others.filter { (inbox.unread[$0.id] ?? 0) > 0 } }

    private var toggleHelp: String {
        if open { return appearance.string("mail.deck.hide") }
        let names = waiting.map(\.mailboxName)
        return names.isEmpty ? appearance.string("mail.deck.show") : appearance.format("mail.deck.showUnread", names.joined(separator: ", "))
    }

    private var footShape: UnevenRoundedRectangle {
        let radius = open ? CGFloat(Tokens.Radius.card) : 0
        return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius, bottomTrailingRadius: radius, topTrailingRadius: 0)
    }

    var body: some View {
        let foot = CGFloat(Tokens.Spacing.step44)
        let count = others.count
        ZStack(alignment: .top) {
            ForEach(Array(others.enumerated()), id: \.element.id) { level, account in
                AccountCard(account: account, level: level, last: level == count - 1,
                            alert: (inbox.unread[account.id] ?? 0) > 0) {
                    pick(account, level: level)
                }
                .frame(height: foot + foot * CGFloat(open ? level + 1 : 0))
                .animation(cardMotion(level, count: count), value: open)
                .zIndex(Double(count - level))
            }
            ComposeHead(account: current) { _ = inbox.compose() }
                .opacity(arrived ? 1 : 0)
                .background(appearance.color(\.lane))
                .lacquer(footShape, gloss: \.stackGlossFront, seam: \.stackSeamFront, drop: true, shown: open)
                .overlay(alignment: .topTrailing) {
                    if !others.isEmpty {
                        EnvelopeButton(open: open, alert: !open && !waiting.isEmpty, help: toggleHelp) { shut.toggle() }
                            .padding(CGFloat(Tokens.Spacing.step8))
                    }
                }
                .zIndex(Double(count + 1))
            if let ghost {
                MailboxGhost(account: ghost.account, level: ghost.level, lifted: lifted, faded: lifted)
                    .zIndex(Double(count + 2))
            }
        }
        .frame(height: foot + foot * CGFloat(open ? count : 0), alignment: .top)
        .frame(maxWidth: .infinity)
        .animation(open ? appearance.ease(Tokens.Duration.deckOpen, Tokens.Easing.deckOpen)
                        : appearance.ease(Tokens.Duration.deckClose, Tokens.Easing.deckClose), value: open)
    }

    private func pick(_ account: Inlet, level: Int) {
        guard !session.mailboxSwitching, ghost == nil else { return }
        session.switchMailbox(account.id, appearance: appearance)
        guard !appearance.still else { return }
        lifted = false
        arrived = false
        ghost = (account, level)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(SheetValues.ghostStart))
            lifted = true
            withAnimation(appearance.ease(Tokens.Duration.switchContentFade, Tokens.Easing.glassOut, delay: Tokens.Duration.switchFade)) { arrived = true }
            try? await Task.sleep(for: .seconds(SheetValues.ghostLife))
            ghost = nil
            lifted = false
        }
    }

    private func cardMotion(_ level: Int, count: Int) -> Animation? {
        open
            ? appearance.ease(Tokens.Duration.deckOpen, Tokens.Easing.deckOpen, delay: Double(level) * Tokens.Duration.deckOpenStagger)
            : appearance.ease(Tokens.Duration.deckClose, Tokens.Easing.deckClose, delay: Double(count - 1 - level) * Tokens.Duration.deckCloseStagger)
    }
}
