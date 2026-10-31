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
                .overlay(alignment: .trailing) { pill.fixedSize() }
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
