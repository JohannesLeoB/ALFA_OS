import AppKit
import Design
import Shell
import SwiftUI

struct Blob: View {
    let session: AppSession
    let pointer: CGPoint?
    @Binding var frame: CGRect
    @Environment(\.appearance) private var appearance
    @State private var pressing = false
    @State private var held: CGPoint?
    @State private var stretch = BlobStretch.none
    @State private var squeezed = false
    @State private var eyes = CGSize.zero
    @State private var sample: PointerSample?
    @State private var lid = LidMotion.idle
    @State private var anchor = BlobAnchor(up: false, right: false)
    @FocusState private var faceFocused: Bool
    @State private var facePointer = false

    private var desk: DeskState { session.desk }

    var body: some View {
        let measure = desk.measure
        let open = desk.mode != nil
        let docked = desk.docked
        let origin = held ?? CGPoint(x: desk.blobOrigin.x, y: desk.blobOrigin.y)
        let up = open && Double(origin.y) + measure.blobHeight / 2 > desk.window.height / 2
        let right = desk.blob.edge == .trailing && (open || docked)
        let place = BlobAnchor(up: up, right: right)
        let width = CGFloat(desk.blobWidth)
        let shape = UnevenRoundedRectangle(cornerRadii: radii(docked: docked, right: desk.blob.edge == .trailing))
        let resize = appearance.ease(Tokens.Duration.blobWidth)
        let flight = appearance.still || held != nil || place != anchor ? nil : appearance.ease(Tokens.Transition.blobFlight)

        VStack(spacing: 0) {
            if up { content(up: up) }
            face(open: open, docked: docked)
            if !up { content(up: up) }
        }
        .animation(resize) { $0.frame(width: width) }
        .foregroundStyle(appearance.color(\.onInverse))
        .background(appearance.color(\.inverse))
        .animation(resize) { $0.clipShape(shape) }
        .shadowLayers(shape)
        .overlay(alignment: up ? .bottom : .top) {
            if faceFocused && !facePointer {
                RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.blob + Tokens.Size.focusRingOffset + Tokens.Size.focusRingWidth))
                    .strokeBorder(appearance.color(\.focus), lineWidth: CGFloat(Tokens.Size.focusRingWidth))
                    .frame(height: CGFloat(measure.blobHeight))
                    .padding(-CGFloat(Tokens.Size.focusRingOffset + Tokens.Size.focusRingWidth))
                    .allowsHitTesting(false)
            }
        }
        .blobStretch(stretch, squeeze: squeezed ? SheetValues.pressScale : 1)
        .onHover { desk.setHovering($0) }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Frame.space)) } action: { frame = $0 }
        .animation(flight) {
            $0.padding(padding(origin: origin, open: open, docked: docked, up: up, right: right))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(up: up, right: right))
        }
        .onChange(of: place, initial: true) { _, next in anchor = next }
        .onChange(of: pointer) { _, next in follow(next) }
        .task { await blinkLoop() }
    }

    private func radii(docked: Bool, right: Bool) -> RectangleCornerRadii {
        let r = CGFloat(Tokens.Radius.blob)
        guard docked else { return RectangleCornerRadii(topLeading: r, bottomLeading: r, bottomTrailing: r, topTrailing: r) }
        return right
            ? RectangleCornerRadii(topLeading: r, bottomLeading: r, bottomTrailing: 0, topTrailing: 0)
            : RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: r, topTrailing: r)
    }

    private func alignment(up: Bool, right: Bool) -> Alignment {
        switch (up, right) {
        case (false, false): .topLeading
        case (false, true): .topTrailing
        case (true, false): .bottomLeading
        case (true, true): .bottomTrailing
        }
    }

    private func padding(origin: CGPoint, open: Bool, docked: Bool, up: Bool, right: Bool) -> EdgeInsets {
        let margin = CGFloat(desk.measure.margin)
        let top = up ? 0 : origin.y
        let bottom = up ? CGFloat(desk.window.height) - origin.y - CGFloat(desk.measure.blobHeight) : 0
        if open { return EdgeInsets(top: top, leading: right ? 0 : margin, bottom: bottom, trailing: right ? margin : 0) }
        if docked { return EdgeInsets(top: top, leading: 0, bottom: bottom, trailing: 0) }
        return EdgeInsets(top: top, leading: origin.x, bottom: bottom, trailing: 0)
    }

    private func face(open: Bool, docked: Bool) -> some View {
        let orbFace = desk.assistantOpen && desk.face == .orb
        let label = (desk.awake && !open && !docked) || orbFace
        let dot = !open && !docked && session.assistantUnseen
        return HStack(spacing: 0) {
            if orbFace {
                ThinkingOrb(size: Tokens.Size.symbolSize)
            } else {
                BlobEyes(ring: !docked, open: desk.awake || open || pressing, follow: eyes, lid: lid)
            }
            appearance.text(orbFace ? "shell.blobFace.assistant" : desk.current?.titleKey ?? "")
                .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                .lineLimit(1)
                .fixedSize()
                .opacity(label ? 1 : 0)
                .animation(appearance.ease(Tokens.Duration.toggle, delay: Tokens.Duration.labelDelay), value: label)
                .frame(maxWidth: label ? SheetValues.labelMaxWidth : 0, alignment: .leading)
                .clipped()
                .animation(appearance.ease(Tokens.Duration.blobWidth), value: label)
                .padding(.leading, label ? CGFloat(Tokens.Size.menuRowGap) : 0)
            if desk.menuOpen {
                BlobSearch(desk: desk)
            }
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.blobInset))
        .frame(maxWidth: .infinity, alignment: docked ? .center : .leading)
        .frame(height: CGFloat(desk.measure.blobHeight))
        .overlay(alignment: .topTrailing) {
            if dot { NoticeDot().padding(CGFloat(Tokens.Spacing.step8)) }
        }
        .contentShape(Rectangle())
        .focusable()
        .focused($faceFocused)
        .focusEffectDisabled()
        .onChange(of: faceFocused) { _, now in facePointer = now && NSApp.currentEvent?.type != .keyDown }
        .onChange(of: pressing) { _, now in if now { facePointer = true } }
        .dwellHint("shell.blobFace.tooltip", focused: faceFocused && !facePointer)
        .blobPress(desk: desk, held: $held, stretch: $stretch, squeezed: $squeezed, pressing: $pressing, tap: tap)
        .pointerStyle(held != nil ? .grabActive : open ? .default : .grabIdle)
        .onKeyPress(keys: [.return, .space]) { _ in
            tap(count: 1)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(appearance.text(desk.current?.titleKey ?? ""))
        .accessibilityAction { tap(count: 1) }
        .accessibilityAction(named: appearance.text("shell.blobFace.assistant")) { tap(count: 2) }
    }

    @ViewBuilder
    private func content(up: Bool) -> some View {
        if desk.menuOpen {
            BlobMenu(session: session, up: up)
        } else if desk.assistantOpen {
            AssistantPanel(session: session)
        }
    }

    private func tap(count: Int) {
        if count == 2 {
            if !appearance.still { lid = LidMotion.start(.wink) }
            desk.toggleAssistant()
            return
        }
        guard count == 1 else { return }
        desk.toggleMenu()
    }

    private func follow(_ point: CGPoint?) {
        guard !pressing, !desk.laneDragging else { return }
        guard let point else {
            desk.setAwake(false)
            return
        }
        let measure = desk.measure
        let origin = desk.blobOrigin
        let cx = origin.x + measure.blobWidth / 2
        let cy = origin.y + measure.blobHeight / 2
        let dist = hypot(Double(point.x) - cx, Double(point.y) - cy)
        let now = Date.timeIntervalSinceReferenceDate
        let here = BlobPoint(x: Double(point.x), y: Double(point.y))
        let last = sample ?? PointerSample(point: here, time: now)
        let speed = hypot(here.x - last.point.x, here.y - last.point.y) / max(ShellValues.pointerStep, now - last.time)
        sample = PointerSample(point: here, time: now)
        let fast = speed > Tokens.Motion.blobFlingSpeed && dist > Tokens.Size.blobFlingMinDistance && !desk.awake
        desk.setAwake(dist < Tokens.Size.blobWakeDistance && !fast)
        guard !appearance.still else { return }
        let reach = dist < Tokens.Size.blobEyeFollowDistance ? min(1, dist / Tokens.Size.blobEyeFollowRamp) : 0
        let angle = atan2(Double(point.y) - cy, Double(point.x) - cx)
        eyes = CGSize(width: cos(angle) * Tokens.Size.blobEyeTravelX * reach, height: sin(angle) * Tokens.Size.blobEyeTravelY * reach)
    }

    private func blinkLoop() async {
        while !Task.isCancelled {
            let pause = Tokens.Duration.blobBlinkInterval + Double.random(in: 0..<Tokens.Duration.blobBlinkInterval)
            try? await Task.sleep(for: .seconds(pause))
            if !appearance.still && (desk.awake || desk.mode != nil) { lid = LidMotion.start(.blink) }
        }
    }
}

struct BlobAnchor: Equatable {
    let up: Bool
    let right: Bool
}

struct NoticeDot: View {
    @Environment(\.appearance) private var appearance
    @State private var progress = 0.0

    var body: some View {
        let size = CGFloat(Tokens.Spacing.step4)
        Circle()
            .fill(.foreground)
            .frame(width: size, height: size)
            .pulse(progress: progress)
            .onAppear {
                guard let pulse = appearance.ease(Tokens.Duration.pulse) else { return }
                withAnimation(pulse.repeatForever(autoreverses: false)) { progress = 1 }
            }
    }
}

enum LidKind: Equatable {
    case blink
    case wink
}

struct LidMotion: Equatable {
    let kind: LidKind?
    let serial: Int

    static let idle = LidMotion(kind: nil, serial: 0)

    static func start(_ kind: LidKind) -> LidMotion {
        LidMotion(kind: kind, serial: Int.random(in: 1..<Int.max))
    }
}

struct BlobEyes: View {
    @Environment(\.appearance) private var appearance
    let ring: Bool
    let open: Bool
    let follow: CGSize
    let lid: LidMotion
    @State private var progress = 1.0

    var body: some View {
        let size = CGFloat(Tokens.Size.symbolSize)
        HStack(spacing: CGFloat(Tokens.Size.blobEyeGap)) {
            eye
            eye
        }
        .lidShift(
            progress: progress,
            kind: lid.kind,
            scale: open ? 1 : SheetValues.lidRestScale,
            shift: open ? 0 : Tokens.Size.blobLidOffset
        )
        .animation(appearance.ease(Tokens.Duration.blobEyes), value: open)
        .offset(follow)
        .animation(nil, value: follow)
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.foreground, lineWidth: CGFloat(Tokens.Size.hairline)).opacity(ring ? 1 : 0))
        .onChange(of: lid) { _, next in run(next) }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.stroke))
            .fill(.foreground)
            .frame(width: CGFloat(Tokens.Size.blobEyeWidth), height: CGFloat(Tokens.Size.blobEyeHeight))
    }

    private func run(_ motion: LidMotion) {
        guard let kind = motion.kind else { return }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0 }
        let animation: Animation = kind == .blink
            ? .linear(duration: Tokens.Duration.blobBlinkClose)
            : .timingCurve(Tokens.Easing.standard.x1, Tokens.Easing.standard.y1, Tokens.Easing.standard.x2, Tokens.Easing.standard.y2, duration: Tokens.Duration.blink)
        Task { @MainActor in
            withAnimation(animation) { progress = 1 }
        }
    }
}

struct BlobMenu: View {
    let session: AppSession
    let up: Bool
    @Environment(\.appearance) private var appearance
    @State private var reel = false
    @State private var height = CGFloat.zero
    @State private var aim: Task<Void, Never>?

    private var desk: DeskState { session.desk }

    var body: some View {
        let lines = desk.menuLines(title: { appearance.string($0) })
        let room = CGFloat(desk.blob.menuRoom(window: desk.window, measure: desk.measure))
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                line.padding(.horizontal, CGFloat(Tokens.Size.menuSeparatorInset)).padding(.bottom, CGFloat(Tokens.Spacing.step8))
                ForEach(Array(lines.enumerated()), id: \.element.id) { index, item in
                    reeled(index) {
                        switch item {
                        case .separator:
                            line.padding(.horizontal, CGFloat(Tokens.Size.menuSeparatorInset)).padding(.vertical, CGFloat(Tokens.Size.menuSeparatorSpace))
                        case .entry(let entry, let hit):
                            row(entry, hit: hit)
                        }
                    }
                }
                if lines.isEmpty {
                    appearance.text("menu.empty")
                        .opacity(SheetValues.mutedOpacity)
                        .padding(.horizontal, CGFloat(Tokens.Size.menuRowPadding))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: CGFloat(Tokens.Size.menuRowHeight))
                }
            }
            .padding(.horizontal, CGFloat(Tokens.Size.menuEdge))
            .padding(.bottom, CGFloat(Tokens.Size.menuEdge))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollIndicators(.never)
        .frame(height: min(height, room))
        .font(.face(Tokens.TextSize.body))
        .onHover { inside in if !inside { leave() } }
        .task {
            if appearance.still {
                reel = true
                return
            }
            try? await Task.sleep(for: .seconds(Tokens.Duration.menuReelDelay))
            reel = true
        }
    }

    private var line: some View {
        Rectangle().fill(appearance.color(\.inverseLine)).frame(height: CGFloat(Tokens.Size.hairline))
    }

    private func reeled<Content: View>(_ index: Int, @ViewBuilder _ content: () -> Content) -> some View {
        let delay = Double(min(index, Tokens.Count.menuStaggerMax)) * Tokens.Duration.reelStagger
        let shown = reel || appearance.still
        return content()
            .reel(angle: shown ? 0 : (up ? Tokens.Motion.menuReelTilt : -Tokens.Motion.menuReelTilt), bottom: up)
            .animation(appearance.ease(Tokens.Duration.menuReelTransform, delay: delay), value: shown)
            .opacity(shown ? 1 : 0)
            .animation(appearance.ease(Tokens.Duration.rowSequence, delay: delay), value: shown)
    }

    private func row(_ entry: AppEntry, hit: Int) -> some View {
        let current = entry.id == desk.currentID
        let count = session.panes[entry.id]?.badge ?? 0
        return HStack(spacing: CGFloat(Tokens.Size.menuRowGap)) {
            appearance.text(entry.titleKey)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if count > 0 {
                Text(verbatim: String(count))
                    .font(.face(Tokens.TextSize.small))
                    .monospacedDigit()
                    .opacity(SheetValues.mutedOpacity)
            }
        }
        .font(.face(Tokens.TextSize.body, weight: current ? Tokens.Weight.semibold : Tokens.Weight.regular))
        .padding(.horizontal, CGFloat(Tokens.Size.menuRowPadding))
        .frame(height: CGFloat(Tokens.Size.menuRowHeight))
        .background(
            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
                .fill(desk.hot == hit ? appearance.color(\.inverseHot) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { inside in if inside { target(hit) } }
        .onTapGesture { desk.select(entry.id) }
        .accessibilityAddTraits(.isButton)
    }

    private func target(_ hit: Int) {
        guard desk.hot != hit else { return }
        aim?.cancel()
        aim = Task {
            try? await Task.sleep(for: .seconds(Tokens.Duration.menuHoverDelay))
            guard !Task.isCancelled else { return }
            desk.aim(hit)
        }
    }

    private func leave() {
        aim?.cancel()
        desk.clearHot()
    }
}

struct BlobSearch: View {
    @Bindable var desk: DeskState
    @Environment(\.appearance) private var appearance
    @FocusState private var focused: Bool
    @State private var tape = 0.0
    @State private var fade = 0.0

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Size.menuRowGap)) {
            ZStack(alignment: .leading) {
                if desk.query.isEmpty {
                    appearance.text("menu.search")
                        .opacity(SheetValues.placeholderOpacity)
                        .allowsHitTesting(false)
                }
                TextField("", text: $desk.query)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onKeyPress(.downArrow) { step(down: true) }
                    .onKeyPress(.upArrow) { step(down: false) }
                    .onKeyPress(.escape) {
                        desk.close()
                        return .handled
                    }
                    .onSubmit { desk.chooseHot(entries) }
                    .accessibilityLabel(appearance.text("menu.search"))
            }
            .font(.face(Tokens.TextSize.body))
            .searchFade(progress: fade)
            Glyph(.search)
                .opacity(SheetValues.iconOpacity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(Tokens.Size.symbolSize))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.foreground)
                .frame(height: CGFloat(Tokens.Size.hairline))
                .scaleEffect(x: CGFloat(tape), y: 1, anchor: .trailing)
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(Tokens.Spacing.step16))
        .task {
            if appearance.still {
                tape = 1
                fade = 1
            } else {
                withAnimation(appearance.ease(Tokens.Duration.searchUnderline)) { tape = 1 }
                withAnimation(.linear(duration: Tokens.Duration.searchUnderline)) { fade = 1 }
            }
            try? await Task.sleep(for: .seconds(Tokens.Duration.menuFocusDelay))
            focused = true
        }
    }

    private var entries: [AppEntry] {
        desk.menuLines(title: { appearance.string($0) }).compactMap(\.entry)
    }

    private func step(down: Bool) -> KeyPress.Result {
        let count = entries.count
        guard count > 0 else { return .ignored }
        desk.moveHot(down: down, count: count)
        return .handled
    }
}

private struct LidEffect: ViewModifier, Animatable {
    var progress: Double
    let kind: LidKind?
    var scale: Double
    var shift: Double

    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(progress, AnimatablePair(scale, shift)) }
        set {
            progress = newValue.first
            scale = newValue.second.first
            shift = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        if let kind, progress < 1 {
            content.scaleEffect(x: 1, y: CGFloat(Self.value(kind, progress)))
        } else {
            content.scaleEffect(x: 1, y: CGFloat(scale)).offset(y: CGFloat(shift))
        }
    }

    static func value(_ kind: LidKind, _ t: Double) -> Double {
        let p = min(1, max(0, t))
        switch kind {
        case .blink:
            let low = SheetValues.blinkScale
            let mid = SheetValues.keyframeMiddle
            return p < mid ? 1 - (1 - low) * p / mid : low + (1 - low) * (p - mid) / (1 - mid)
        case .wink:
            let low = SheetValues.winkScale
            let close = SheetValues.winkCloseAt
            let open = SheetValues.winkOpenAt
            if p < close { return 1 - (1 - low) * p / close }
            if p < open { return low }
            return low + (1 - low) * (p - open) / (1 - open)
        }
    }
}

extension View {
    func lidShift(progress: Double, kind: LidKind?, scale: Double, shift: Double) -> some View {
        modifier(LidEffect(progress: progress, kind: kind, scale: scale, shift: shift))
    }
}

private struct ReelEffect: GeometryEffect {
    var angle: Double
    let bottom: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let pivotX = size.width / 2
        let pivotY = bottom ? size.height : 0
        var form = CATransform3DIdentity
        form.m34 = -1 / CGFloat(Tokens.Size.menuReelPerspective)
        form = CATransform3DRotate(form, CGFloat(angle * .pi / SheetValues.halfTurn), 1, 0, 0)
        let toPivot = CATransform3DMakeTranslation(-pivotX, -pivotY, 0)
        let back = CATransform3DMakeTranslation(pivotX, pivotY, 0)
        return ProjectionTransform(CATransform3DConcat(CATransform3DConcat(toPivot, form), back))
    }
}

extension View {
    func reel(angle: Double, bottom: Bool) -> some View {
        modifier(ReelEffect(angle: angle, bottom: bottom))
    }
}

private struct PulseEffect: ViewModifier, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let peak = SheetValues.pulseScale
        let p = min(1, max(0, progress))
        let mid = SheetValues.keyframeMiddle
        let scale = p < mid ? 1 + (peak - 1) * p / mid : peak - (peak - 1) * (p - mid) / (1 - mid)
        content.scaleEffect(CGFloat(scale))
    }
}

extension View {
    func pulse(progress: Double) -> some View {
        modifier(PulseEffect(progress: progress))
    }
}
