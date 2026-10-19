import ShellCore
import SwiftUI

enum ConfirmPhase {
    case rest
    case ask
    case running
    case done
}

struct ConfirmPill<Glyph: View>: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
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
    @State private var hold: Hold?
    @State private var job: Task<Void, Never>?

    private struct Hold: Equatable {
        let from: Double
        let forward: Bool
        let start: Date

        var length: Double {
            forward ? Design.Duration.confirmHold * (1 - from) : Design.Duration.confirmRelease * from
        }

        func fill(at date: Date) -> Double {
            let k = length <= 0 ? 1 : min(1, max(0, date.timeIntervalSince(start) / length))
            return forward ? from + (1 - from) * k : from - from * k
        }
    }

    private var current: ConfirmPhase { phase ?? (startsAsking ? .ask : .rest) }
    private var motion: Animation? { ComponentMotion(reduced: reduced).curve(Design.Duration.toggle) }

    var body: some View {
        if startsAsking {
            pill
        } else {
            restContent
                .padding(CGFloat(Design.Spacing.step4))
                .frame(height: CGFloat(Design.Spacing.step28))
                .hidden()
                .overlay(alignment: .trailing) { pill.fixedSize() }
        }
    }

    private var pill: some View {
        let asking = current == .ask
        return ZStack {
            switch current {
            case .rest: restContent.transition(enter)
            case .ask: askContent.transition(enter)
            case .running: runningContent.transition(enter)
            case .done: doneContent.transition(enter)
            }
        }
        .font(.system(size: CGFloat(Design.TextSize.body)))
        .foregroundStyle(design.color(\.ink))
        .padding(CGFloat(Design.Spacing.step4))
        .frame(height: CGFloat(Design.Spacing.step28))
        .background(Capsule().fill(asking ? design.color(\.well) : Color.clear))
        .ring(Capsule(), asking ? design.color(\.line) : nil)
        .onDisappear { job?.cancel() }
    }

    private var enter: AnyTransition {
        reduced ? .identity : .modifier(active: ConfirmEnter(amount: 1), identity: ConfirmEnter(amount: 0))
    }

    private var restContent: some View {
        InnerButton(action: { change(.ask) }) {
            HStack(spacing: CGFloat(Design.Spacing.step4)) {
                glyph
                if let label { sized(label) }
            }
        }
    }

    private var askContent: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            question
                .lineLimit(1)
                .foregroundStyle(design.color(\.ink))
            InnerButton(action: decline) { no }
            yesButton
        }
        .padding(.leading, CGFloat(Design.Spacing.step8))
    }

    private var yesButton: some View {
        TimelineView(.animation(paused: hold == nil)) { context in
            let fill = hold?.fill(at: context.date) ?? 0
            sized(yes)
                .font(.system(size: CGFloat(Design.TextSize.small), weight: .design(Design.Weight.medium)))
                .foregroundStyle(design.color(\.signal))
                .padding(.horizontal, CGFloat(Design.Spacing.step8))
                .frame(height: CGFloat(Design.Spacing.step20))
                .ring(Capsule(), design.color(\.signal))
                .contentShape(Capsule())
                .mask { erase(fill) }
                .blur(radius: CGFloat(fill * Design.Confirm.eraseBlur))
                .offset(x: CGFloat(shake(fill)))
        }
        .help(holdHint)
        .accessibilityAddTraits(.isButton)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in press() }
                .onEnded { _ in release() }
        )
        .onHover { inside in if !inside { release() } }
        .focusable()
        .onKeyPress(.return) { confirm(); return .handled }
        .onKeyPress(.space) { confirm(); return .handled }
        .onKeyPress(.escape) { decline(); return .handled }
    }

    private var runningContent: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            ConfirmSpinner()
            if let running { running }
        }
        .font(.system(size: CGFloat(Design.TextSize.small), weight: .design(Design.Weight.medium)))
        .foregroundStyle(design.color(\.inkSecondary))
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
    }

    private var doneContent: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            if let done { done.foregroundStyle(design.color(\.ink)) }
            if let undo {
                InnerButton(action: revert) { undo }
            }
        }
        .font(.system(size: CGFloat(Design.TextSize.small), weight: .design(Design.Weight.medium)))
        .padding(.leading, CGFloat(Design.Spacing.step8))
        .padding(.trailing, CGFloat(Design.Spacing.step4))
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
        guard fill > 0 else { return LinearGradient(colors: [.black], startPoint: .leading, endPoint: .trailing) }
        let edge = Design.Confirm.eraseEdge
        let low = fill * (1 + edge) - edge
        let high = fill * (1 + edge)
        func alpha(_ x: Double) -> Double { min(1, max(0, (x - low) / edge)) }
        let a = min(1, max(0, low))
        let b = min(1, max(0, high))
        let stops = [
            Gradient.Stop(color: .black.opacity(alpha(0)), location: 0),
            Gradient.Stop(color: .black.opacity(alpha(a)), location: a),
            Gradient.Stop(color: .black.opacity(alpha(b)), location: b),
            Gradient.Stop(color: .black.opacity(alpha(1)), location: 1)
        ]
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    private func shake(_ fill: Double) -> Double {
        let start = Design.Confirm.shakeFrom
        guard fill > start else { return 0 }
        return sin(fill * Design.Confirm.shakeFrequency) * Design.Confirm.shakeAmplitude * (fill - start) / (1 - start)
    }

    private func change(_ next: ConfirmPhase) {
        withAnimation(motion) { phase = next }
    }

    private func press() {
        guard current == .ask, hold?.forward != true else { return }
        if reduced { confirm(); return }
        run(forward: true)
    }

    private func release() {
        guard current == .ask, let hold, hold.forward else { return }
        run(forward: false)
    }

    private func run(forward: Bool) {
        let now = Date()
        let from = hold?.fill(at: now) ?? 0
        let next = Hold(from: from, forward: forward, start: now)
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
            try? await Task.sleep(for: .seconds(Design.Duration.confirmDoneDelay))
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
    @Environment(\.design) private var design
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: CGFloat(Design.TextSize.small), weight: .design(Design.Weight.medium)))
                .foregroundStyle(design.color(hovering ? \.ink : \.inkSecondary))
                .padding(.horizontal, CGFloat(Design.Spacing.step8))
                .frame(height: CGFloat(Design.Spacing.step20))
                .background(Capsule().fill(hovering ? design.color(\.hover) : Color.clear))
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
            .blur(radius: CGFloat(amount * Design.Size.confirmEnterBlur))
    }
}

private struct ConfirmSpinner: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var turning = false

    var body: some View {
        let side = CGFloat(Design.Spacing.step12)
        let stroke = CGFloat(Design.Size.spinnerStroke)
        let quarter = 1.0 / 4
        ZStack {
            Circle().strokeBorder(design.color(\.lineStrong), lineWidth: stroke)
            Circle()
                .inset(by: stroke / 2)
                .trim(from: 0, to: quarter)
                .stroke(design.color(\.ink), lineWidth: stroke)
                .rotationEffect(.degrees(-360 * (quarter + quarter / 2)))
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(turning ? 360 : 0))
        .animation(reduced ? nil : .linear(duration: Design.Duration.spinner).repeatForever(autoreverses: false), value: turning)
        .onAppear { turning = true }
    }
}
