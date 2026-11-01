import AppKit
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
        if waiting.isEmpty { return appearance.string("mail.deck.show") }
        let names = waiting.map { $0.shownName(settings.display($0.id), appearance: appearance) }
        return appearance.format("mail.deck.showUnread", ListFormatter.localizedString(byJoining: names))
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

struct AccountCard: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let level: Int
    let last: Bool
    let alert: Bool
    let named: Bool
    let choose: (MailboxDisplay) -> Void
    let action: () -> Void
    @State private var hovering = false
    @State private var anchor = AnchorBox()

    private var step: StackStep { appearance.stackStep(level) }

    var body: some View {
        let ink = appearance.paint(step.ink)
        let shape = Deck.bottomRounded(Tokens.Radius.card)
        Button(action: action) {
            MailboxRow(account: account, display: display, ink: ink, alert: alert, named: named)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .background(appearance.paint(step.surface).animation(appearance.ease(Tokens.Duration.stackBackground, Tokens.Easing.stack), value: level))
                .lacquer(shape, step: step, seam: \.stackSeamBack, drop: !last)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .overlay {
            RightClickOverlay { point in
                MailboxMenu.show(for: account, current: display, at: point, appearance: appearance, choose: choose)
            }
        }
        .background(AnchorMarker(box: anchor))
        .offset(y: !last && hovering ? CGFloat(Tokens.Spacing.step4) : 0)
        .onHover { hovering = $0 }
        .help(Text(verbatim: account.account))
        .accessibilityLabel(Text(verbatim: account.account))
        .accessibilityValue(alert ? appearance.text("mail.row.unread") : Text(verbatim: ""))
        .accessibilityAction(named: appearance.text("settings.account.show")) {
            anchor.showMenu(MailboxMenu.entries(for: account, current: display, appearance: appearance, choose: choose))
        }
        .animation(appearance.ease(SheetValues.deckLift, Tokens.Easing.envelopeSpring), value: hovering)
    }
}

struct AccountTitle: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let choose: (MailboxDisplay) -> Void
    @State private var anchor = AnchorBox()

    var body: some View {
        Text(verbatim: account.shownName(display, appearance: appearance))
            .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step28), alignment: .leading)
            .contentShape(Rectangle())
            .help(Text(verbatim: account.account))
            .overlay {
                RightClickOverlay { point in
                    MailboxMenu.show(for: account, current: display, at: point, appearance: appearance, choose: choose)
                }
            }
            .background(AnchorMarker(box: anchor))
            .accessibilityAction(named: appearance.text("settings.account.show")) {
                anchor.showMenu(MailboxMenu.entries(for: account, current: display, appearance: appearance, choose: choose))
            }
    }
}

struct AccountAlert: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        let line = CGFloat(Tokens.Size.hairline)
        Circle()
            .fill(appearance.color(\.signal))
            .frame(width: CGFloat(Tokens.Spacing.step8), height: CGFloat(Tokens.Spacing.step8))
            .offset(x: line, y: -line)
            .allowsHitTesting(false)
    }
}

struct MailboxRow: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let ink: Color
    var alert = false
    var named = true
    var trailing = Deck.toggleRoom

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        DeckRow(trailing: trailing) {
            Text(verbatim: account.mailboxInitials)
                .typeStyle(Tokens.TextStyle.mark)
                .lineLimit(1)
                .frame(width: side, height: side)
                .ring(Circle(), ink.opacity(Tokens.Opacity.ringOnMark))
                .overlay(alignment: .topTrailing) { if alert { AccountAlert() } }
        } label: {
            Text(verbatim: account.shownName(display, appearance: appearance))
                .typeStyle(Tokens.TextStyle.bodyEmphasis)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(named ? 1 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MailboxGhost: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let level: Int
    let lifted: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
        let ink = appearance.color(\.ink)
        MailboxRow(account: account, display: display, ink: ink, trailing: Deck.inset)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .animation(appearance.ease(Tokens.Duration.switchFade, Tokens.Easing.glassIn)) {
                $0.background(lifted ? appearance.color(\.lane) : appearance.paint(appearance.stackStep(level).surface), in: shape)
            }
            .animation(appearance.ease(Tokens.Duration.switchFade, Tokens.Easing.glassIn)) {
                $0.ring(shape, appearance.color(lifted ? \.line : \.ghostRing))
                    .background {
                        shape.inset(by: CGFloat(-Tokens.Size.ghostShadowSpread))
                            .fill(lifted ? appearance.color(\.ghostShadow) : Color.clear)
                            .blur(radius: CGFloat(Tokens.Size.ghostShadowBlur / 2))
                            .offset(y: CGFloat(Tokens.Size.ghostShadowOffset))
                    }
            }
            .animation(appearance.ease(Tokens.Duration.switchLift, Tokens.Easing.glassOut)) {
                $0.offset(y: lifted ? 0 : Deck.height(level))
            }
            .animation(appearance.ease(Tokens.Duration.switchGhostFade, Tokens.Easing.glassIn, delay: Tokens.Duration.switchFade)) {
                $0.opacity(lifted ? 0 : 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

@MainActor
enum MailboxMenu {
    static func entries(for account: Inlet, current: MailboxDisplay, appearance: Appearance,
                        choose: @escaping (MailboxDisplay) -> Void) -> [MenuEntry] {
        let own = account.shownTitle(appearance)
        return [.head(id: "mailbox.display", label: appearance.text("settings.account.show"))] + MailboxDisplay.allCases.map { option in
            let label: Text
            var meta: Text?
            switch option {
            case .ownName:
                label = own.isEmpty ? appearance.text("settings.account.show.own") : Text(verbatim: own)
                meta = own.isEmpty ? appearance.text("mail.account.show.inSettings") : nil
            case .localPart: label = Text(verbatim: MailboxDisplay.local(account.account))
            case .domain: label = Text(verbatim: MailboxDisplay.domain(account.account))
            }
            return .row(MenuItem(id: option.rawValue, label: label, meta: meta,
                                 check: option == current ? appearance.text("mail.menu.check") : nil) { choose(option) })
        }
    }

    static func show(for account: Inlet, current: MailboxDisplay, at point: NSPoint, appearance: Appearance,
                     choose: @escaping (MailboxDisplay) -> Void) {
        MenuPanel.shared.show(entries: entries(for: account, current: current, appearance: appearance, choose: choose),
                              anchor: .point(point), window: NSApp.keyWindow)
    }
}

extension Inlet {
    func shownTitle(_ appearance: Appearance) -> String {
        appearance.string(title).trimmingCharacters(in: .whitespaces)
    }

    func shownName(_ display: MailboxDisplay, appearance: Appearance) -> String {
        display.text(title: shownTitle(appearance), account: account)
    }
}

struct EnvelopeButton: View {
    @Environment(\.appearance) private var appearance
    let open: Bool
    let alert: Bool
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        Button(action: action) {
            EnvelopeStack(open: open)
                .frame(width: side, height: side)
                .foregroundStyle(appearance.color(hovering ? \.ink : \.inkTertiary))
                .ring(Capsule(), appearance.color(hovering ? \.inkTertiary : \.lineStrong))
                .overlay(alignment: .topTrailing) { if alert { AccountAlert() } }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressButton))
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .accessibilityAddTraits(open ? .isSelected : [])
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
    }
}

struct EnvelopeStack: View {
    @Environment(\.appearance) private var appearance
    let open: Bool

    var body: some View {
        let box = CGFloat(SheetValues.envelopeBox)
        ZStack(alignment: .topLeading) {
            ForEach([2, 1, 0], id: \.self) { index in
                envelope(flap: index == 0)
                    .offset(x: CGFloat((open ? SheetValues.envelopeOpenX : SheetValues.envelopeShutX)[index]),
                            y: CGFloat((open ? SheetValues.envelopeOpenY : SheetValues.envelopeShutY)[index]))
                    .animation(appearance.ease(SheetValues.envelopeTimes[index], Tokens.Easing.envelopeSpring,
                                               delay: (open ? SheetValues.envelopeOpenDelays : SheetValues.envelopeShutDelays)[index]),
                               value: open)
            }
        }
        .frame(width: box, height: box, alignment: .topLeading)
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: CGFloat(Tokens.Size.envelopeStroke), lineCap: .round, lineJoin: .round)
    }

    private func envelope(flap: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(SheetValues.envelopeRadius))
        let inset = CGFloat(SheetValues.envelopeFlapInset)
        return ZStack(alignment: .topLeading) {
            shape.fill(appearance.color(\.lane))
            shape.stroke(style: stroke)
            if flap {
                EnvelopeFlap()
                    .stroke(style: stroke)
                    .frame(width: CGFloat(SheetValues.envelopeWidth) - inset * 2, height: CGFloat(SheetValues.envelopeFlapDepth))
                    .scaleEffect(x: 1, y: open ? -1 : 1, anchor: .top)
                    .offset(x: inset, y: CGFloat(SheetValues.envelopeFlapTop))
                    .animation(open
                               ? appearance.ease(Tokens.Duration.flapOpen, Tokens.Easing.envelopeSpring, delay: Tokens.Duration.flapOpenDelay)
                               : appearance.ease(Tokens.Duration.flapClose, Tokens.Easing.deckClose),
                               value: open)
            }
        }
        .frame(width: CGFloat(SheetValues.envelopeWidth), height: CGFloat(SheetValues.envelopeHeight), alignment: .topLeading)
    }
}

private struct EnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

enum Deck {
    static var row: CGFloat { CGFloat(Tokens.Spacing.step44) }

    static var inset: CGFloat { CGFloat(Tokens.Radius.card - Tokens.Size.symbolSize / 2) }

    static var toggleRoom: CGFloat { CGFloat(Tokens.Spacing.step28 + Tokens.Spacing.step20) }

    static func height(_ rows: Int) -> CGFloat { row + row * CGFloat(rows) }

    static func bottomRounded(_ radius: Double) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: CGFloat(radius), bottomTrailingRadius: CGFloat(radius),
                               topTrailingRadius: 0)
    }
}

struct DeckRow<Mark: View, Label: View>: View {
    var trailing = Deck.toggleRoom
    @ViewBuilder let mark: Mark
    @ViewBuilder let label: Label

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            mark.padding(.trailing, CGFloat(Tokens.Spacing.step12))
            label
        }
        .padding(.leading, Deck.inset)
        .padding(.trailing, trailing)
        .frame(height: Deck.row)
    }
}
