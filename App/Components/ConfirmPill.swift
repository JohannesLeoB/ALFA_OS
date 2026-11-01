import Design
import Shell
import SwiftUI

enum ConfirmPhase {
    case rest
    case ask
    case running
    case done
}

struct ConfirmPill<Glyph: View>: View {
    @Environment(\.appearance) private var appearance
    @Environment(\.appLocked) private var locked
    @Environment(\.pillRoom) private var room
    @GestureState private var touching = false
    var label: Text?
    let question: Text
    let yes: Text
    let no: Text
    var running: Text?
    var done: Text?
    var undo: Text?
    let holdHint: Text
    var startsAsking = false
    var showsProgress = true
    let onYes: () -> Void
    var onNo: () -> Void = {}
    var onUndo: () -> Void = {}
    @ViewBuilder let glyph: Glyph

    @State private var phase: ConfirmPhase?
    @State private var hold: HoldEngine?
    @State private var job: Task<Void, Never>?

    private var current: ConfirmPhase { phase ?? (startsAsking ? .ask : .rest) }

    var body: some View {
        if startsAsking {
            pill
        } else {
            restContent
                .padding(CGFloat(Tokens.Spacing.step4))
                .frame(height: CGFloat(Tokens.Spacing.step28))
                .hidden()
                .overlay(alignment: .trailing) { bounded }
        }
    }

    @ViewBuilder
    private var bounded: some View {
        if let room {
            pill.frame(width: room, alignment: .trailing)
        } else {
            pill.fixedSize()
        }
    }

    private var pill: some View {
        let asking = current == .ask
        let enter = appearance.still ? AnyTransition.identity : AnyTransition.confirmEnter
        return ZStack {
            switch current {
            case .rest: restContent.transition(enter)
            case .ask: askContent.transition(enter)
            case .running: runningContent.transition(enter)
            case .done: doneContent.transition(enter)
            }
        }
        .font(.face(Tokens.TextSize.body))
        .lineHeight(Tokens.LineHeight.control, size: Tokens.TextSize.body)
        .foregroundStyle(appearance.color(\.ink))
        .padding(CGFloat(Tokens.Spacing.step4))
        .frame(height: CGFloat(Tokens.Spacing.step28))
        .background(Capsule().fill(asking ? appearance.color(\.well) : Color.clear))
        .ring(Pill(), asking ? appearance.color(\.line) : nil)
        .onDisappear { job?.cancel() }
    }

    private var restContent: some View {
        InnerButton(action: { change(.ask) }) {
            HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
                glyph
                if let label { sized(label) }
            }
        }
    }

    private var askContent: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            question
                .lineLimit(1)
                .help(question)
                .layoutPriority(-1)
                .foregroundStyle(appearance.color(\.ink))
            InnerButton(action: decline) { no }
            yesButton
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
    }

    private var yesButton: some View {
        TimelineView(.animation(paused: hold == nil)) { context in
            let fill = hold?.fill(at: context.date) ?? 0
            sized(yes)
                .typeStyle(Tokens.TextStyle.captionEmphasis)
                .foregroundStyle(appearance.color(\.signal))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                .frame(height: CGFloat(Tokens.Spacing.step20))
                .ring(Pill(), appearance.color(\.signal))
                .contentShape(Capsule())
                .mask { erase(fill) }
                .blur(radius: CGFloat(fill * Tokens.Confirm.eraseBlur))
                .offset(x: CGFloat(HoldEngine.shake(fill: fill)))
        }
        .help(holdHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirm() }
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($touching) { _, state, _ in state = true }
                .onChanged { _ in press() }
        )
        .onChange(of: touching) { _, now in if !now { release() } }
        .onChange(of: locked) { _, now in if now { release() } }
        .onHover { inside in if !inside { release() } }
        .focusable()
        .onKeyPress(.return) { confirm(); return .handled }
        .onKeyPress(.space) { confirm(); return .handled }
        .onKeyPress(.escape) { decline(); return .handled }
    }

    private var runningContent: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Spinner(side: Tokens.Spacing.step12, arc: SheetValues.confirmSpinnerArc, stroke: Tokens.Size.spinnerStroke,
                    duration: Tokens.Duration.spinner, tone: \.ink, track: \.lineStrong)
            if let running { running }
        }
        .typeStyle(Tokens.TextStyle.captionEmphasis)
        .foregroundStyle(appearance.color(\.inkSecondary))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
    }

    private var doneContent: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            if let done { done.foregroundStyle(appearance.color(\.ink)) }
            if let undo {
                InnerButton(action: revert) { undo }
            }
        }
        .typeStyle(Tokens.TextStyle.captionEmphasis)
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(Tokens.Spacing.step4))
    }

    private func sized(_ text: Text) -> some View {
        ZStack {
            if let label { label.hidden() }
            yes.hidden()
            text
        }
        .lineLimit(1)
    }

    private func erase(_ fill: Double) -> LinearGradient {
        let stops = HoldEngine.eraseStops(fill: fill).map {
            Gradient.Stop(color: appearance.color(\.safeArea).opacity($0.opacity), location: $0.location)
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    private func change(_ next: ConfirmPhase) {
        withAnimation(appearance.ease(Tokens.Duration.toggle)) { phase = next }
    }

    private func press() {
        guard current == .ask, hold?.forward != true else { return }
        if appearance.still { confirm(); return }
        run(forward: true)
    }

    private func release() {
        guard current == .ask, let hold, hold.forward else { return }
        run(forward: false)
    }

    private func run(forward: Bool) {
        let now = Date()
        let from = hold?.fill(at: now) ?? 0
        let next = HoldEngine(from: from, forward: forward, start: now)
        hold = next
        job?.cancel()
        job = Task { @MainActor in
            try? await Task.sleep(for: .seconds(next.length))
            guard !Task.isCancelled, hold == next else { return }
            if forward { confirm() } else { hold = nil }
        }
    }

    private func confirm() {
        guard current == .ask else { return }
        job?.cancel()
        hold = nil
        onYes()
        guard showsProgress else { change(.rest); return }
        change(.running)
        job = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Tokens.Duration.confirmDoneDelay))
            guard !Task.isCancelled else { return }
            change(.done)
        }
    }

    private func decline() {
        job?.cancel()
        hold = nil
        change(.rest)
        onNo()
    }

    private func revert() {
        change(.rest)
        onUndo()
    }
}

extension ConfirmPill where Glyph == EmptyView {
    init(label: Text?, question: Text, yes: Text, no: Text, running: Text? = nil, done: Text? = nil, undo: Text? = nil, holdHint: Text, startsAsking: Bool = false, showsProgress: Bool = true, onYes: @escaping () -> Void, onNo: @escaping () -> Void = {}, onUndo: @escaping () -> Void = {}) {
        self.init(label: label, question: question, yes: yes, no: no, running: running, done: done, undo: undo, holdHint: holdHint, startsAsking: startsAsking, showsProgress: showsProgress, onYes: onYes, onNo: onNo, onUndo: onUndo) { EmptyView() }
    }
}

private struct InnerButton<Label: View>: View {
    @Environment(\.appearance) private var appearance
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .typeStyle(Tokens.TextStyle.captionEmphasis)
                .foregroundStyle(appearance.color(hovering ? \.ink : \.inkSecondary))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                .frame(height: CGFloat(Tokens.Spacing.step20))
                .background(Capsule().fill(hovering ? appearance.color(\.hover) : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct ConfirmEnter: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content
            .opacity(1 - amount)
            .blur(radius: CGFloat(amount * Tokens.Size.confirmEnterBlur))
    }
}

extension AnyTransition {
    static var confirmEnter: AnyTransition {
        .modifier(active: ConfirmEnter(amount: 1), identity: ConfirmEnter(amount: 0))
    }
}

enum ConnectionState {
    case connected
    case connecting
    case working
    case notConnected
    case failed
    case unreadable
}

struct ConnectionStatus: View {
    @Environment(\.appearance) private var appearance
    let state: ConnectionState
    let label: Text
    var inverted = false

    private var ink: InkSet { .of(inverted) }

    private var dotFill: KeyPath<Colors, ColorValue>? {
        switch state {
        case .connected: ink.primary
        case .failed: \.signal
        default: nil
        }
    }

    private var border: KeyPath<Colors, ColorValue> {
        switch state {
        case .connected: ink.primary
        case .connecting, .working, .notConnected: ink.line
        case .failed, .unreadable: \.signal
        }
    }

    private var foreground: KeyPath<Colors, ColorValue> {
        switch state {
        case .connected, .connecting, .working: ink.secondary
        case .notConnected: inverted ? ink.secondary : ink.tertiary
        case .failed, .unreadable: \.signal
        }
    }

    private var spins: Bool { state == .connecting || state == .working }

    var body: some View {
        let dot = CGFloat(Tokens.Spacing.statusDot)
        let line = CGFloat(Tokens.Size.hairline)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            ZStack {
                if let dotFill {
                    Circle().fill(appearance.color(dotFill))
                }
            }
            .frame(width: dot, height: dot)
            .overlay {
                Circle().strokeBorder(appearance.color(border), lineWidth: line)
            }
            .overlay {
                if spins {
                    Spinner(side: SheetValues.statusArcBox, arc: SheetValues.statusArc, stroke: SheetValues.iconStroke,
                            tone: nil, round: true)
                }
            }
            label
                .lineLimit(1)
                .help(label)
                .padding(.trailing, CGFloat(Tokens.Size.trailingTextInset))
        }
        .font(.face(Tokens.TextSize.small))
        .foregroundStyle(appearance.color(foreground))
    }
}

struct Spinner: View {
    @Environment(\.appearance) private var appearance
    var side = Tokens.Size.symbolSize
    var arc = SheetValues.spinnerArc
    var stroke = Tokens.Size.hairline
    var duration = Tokens.Duration.thinking
    var tone: KeyPath<Colors, ColorValue>? = \.ink
    var track: KeyPath<Colors, ColorValue>?
    var round = false
    @State private var turn = 0.0

    var body: some View {
        let line = CGFloat(stroke)
        let style = tone.map { AnyShapeStyle(appearance.color($0)) } ?? AnyShapeStyle(.foreground)
        ZStack {
            if let track {
                Circle().strokeBorder(appearance.color(track), lineWidth: line)
            }
            Circle()
                .inset(by: line / 2)
                .trim(from: 0, to: CGFloat(arc))
                .stroke(style, style: StrokeStyle(lineWidth: line, lineCap: round ? .round : .butt))
        }
        .frame(width: CGFloat(side), height: CGFloat(side))
        .rotationEffect(.degrees(turn))
        .task {
            guard !appearance.still else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) { turn = SheetValues.fullTurn }
        }
    }
}
