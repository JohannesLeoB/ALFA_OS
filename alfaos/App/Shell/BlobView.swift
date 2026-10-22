import AppKit
import ShellCore
import SwiftUI

struct BlobView: View {
    let theme: Theme
    @Bindable var model: ShellModel
    let host: AppHost?
    let pointer: CGPoint?
    @Binding var frame: CGRect
    @State private var press: BlobPress?
    @State private var held: CGPoint?
    @State private var stretch = BlobStretch.none
    @State private var squeezed = false
    @State private var justDragged = false
    @State private var eyes = CGSize.zero
    @State private var sample: PointerSample?
    @State private var lid = LidMotion.idle
    @State private var anchor = BlobAnchor(up: false, right: false)

    private var g: ShellGeometry { theme.geometry }

    var body: some View {
        let open = model.mode != nil
        let docked = model.docked
        let origin = held ?? CGPoint(x: model.blobOrigin.x, y: model.blobOrigin.y)
        let up = open && Double(origin.y) + g.blobHeight / 2 > model.window.height / 2
        let right = model.blob.edge == .trailing && (open || docked)
        let place = BlobAnchor(up: up, right: right)
        let width = CGFloat(model.blobWidth)
        let shape = UnevenRoundedRectangle(cornerRadii: radii(docked: docked, right: model.blob.edge == .trailing))
        let resize = theme.ease(Design.Duration.blobWidth)
        let flight = theme.still || held != nil || place != anchor ? nil : theme.ease(Design.Duration.blobFlight, Design.Easing.blobFlight)

        VStack(spacing: 0) {
            if up { content(up: up) }
            face(open: open, docked: docked)
            if !up { content(up: up) }
        }
        .animation(resize) { $0.frame(width: width) }
        .foregroundStyle(theme.design(\.onInverse))
        .background(theme.design(\.inverse))
        .animation(resize) { $0.clipShape(shape) }
        .themeShadow(theme, layers: theme.designShadow(\.floating), shape: shape)
        .modifier(BlobStretchEffect(stretch: stretch, squeeze: squeezed ? SheetValues.pressScale : 1))
        .onHover { model.setHovering($0) }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("shell")) } action: { frame = $0 }
        .animation(flight) {
            $0.padding(padding(origin: origin, open: open, docked: docked, up: up, right: right))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(up: up, right: right))
        }
        .onChange(of: place, initial: true) { _, next in anchor = next }
        .onChange(of: pointer) { _, next in follow(next) }
        .task { await blinkLoop() }
    }

    private func radii(docked: Bool, right: Bool) -> RectangleCornerRadii {
        let r = CGFloat(Design.Radius.blob)
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
        let margin = CGFloat(g.margin)
        let top = up ? 0 : origin.y
        let bottom = up ? CGFloat(model.window.height) - origin.y - CGFloat(g.blobHeight) : 0
        if open { return EdgeInsets(top: top, leading: right ? 0 : margin, bottom: bottom, trailing: right ? margin : 0) }
        if docked { return EdgeInsets(top: top, leading: 0, bottom: bottom, trailing: 0) }
        return EdgeInsets(top: top, leading: origin.x, bottom: bottom, trailing: 0)
    }

    private func face(open: Bool, docked: Bool) -> some View {
        let orbFace = model.assistantOpen && model.face == .orb
        let label = (model.awake && !open && !docked) || orbFace
        let dot = !open && !docked && ((host?.unread ?? 0) > 0 || host?.syncFailed == true)
        return HStack(spacing: 0) {
            if orbFace {
                ThinkingOrb(theme: theme, size: Design.Size.symbolSize)
            } else {
                BlobEyes(theme: theme, ring: !docked, open: model.awake || open || press != nil, follow: eyes, lid: lid)
            }
            theme.text(orbFace ? "assistant.title" : model.current?.titleKey ?? "")
                .font(theme.font(weight: Design.Weight.medium))
                .lineLimit(1)
                .fixedSize()
                .opacity(label ? 1 : 0)
                .animation(theme.ease(Design.Duration.toggle, delay: Design.Duration.labelDelay), value: label)
                .frame(maxWidth: label ? SheetValues.labelMaxWidth : 0, alignment: .leading)
                .clipped()
                .animation(theme.ease(Design.Duration.blobWidth), value: label)
                .padding(.leading, label ? CGFloat(Design.Size.menuRowGap) : 0)
            if model.menuOpen {
                BlobSearch(theme: theme, model: model)
            }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.blobInset))
        .frame(maxWidth: .infinity, alignment: docked ? .center : .leading)
        .frame(height: CGFloat(g.blobHeight))
        .overlay(alignment: .topTrailing) {
            if dot { NoticeDot(theme: theme).padding(CGFloat(Design.Spacing.step8)) }
        }
        .contentShape(Rectangle())
        .gesture(drag)
        .pointerStyle(held != nil ? .grabActive : open ? .default : .grabIdle)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(theme.text(model.current?.titleKey ?? ""))
    }

    @ViewBuilder
    private func content(up: Bool) -> some View {
        if model.menuOpen {
            BlobMenu(theme: theme, model: model, host: host, up: up)
        } else if model.assistantOpen {
            BlobAssistant(theme: theme, model: model, host: host)
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("shell"))
            .onChanged { value in
                let now = Date.timeIntervalSinceReferenceDate
                if press == nil {
                    let origin = CGPoint(x: model.blobOrigin.x, y: model.blobOrigin.y)
                    press = BlobPress(start: value.startLocation, origin: origin, moved: false, history: [PointerSample(point: value.location, time: now)])
                    if !theme.still { squeezed = true }
                }
                guard var current = press else { return }
                let dx = value.location.x - current.start.x
                let dy = value.location.y - current.start.y
                if !current.moved && hypot(dx, dy) < Design.Size.blobDragThreshold { return }
                if !current.moved {
                    current.moved = true
                    model.beginBlobDrag()
                }
                current.history = Array((current.history + [PointerSample(point: value.location, time: now)]).suffix(SheetValues.releaseSamples))
                press = current
                held = CGPoint(x: current.origin.x + dx, y: current.origin.y + dy)
                squeezed = false
                stretch = theme.still ? .none : BlobStretch(history: current.history)
            }
            .onEnded { _ in
                squeezed = false
                stretch = .none
                guard let current = press else { return }
                press = nil
                guard current.moved, let spot = held else {
                    tap(count: NSApp.currentEvent?.clickCount ?? 1)
                    return
                }
                justDragged = true
                Task {
                    try? await Task.sleep(for: .seconds(Design.Duration.clickGuard))
                    justDragged = false
                }
                let velocity = current.velocity
                held = nil
                model.dropBlob(
                    center: Point(x: Double(spot.x) + g.blobWidth / 2, y: Double(spot.y) + g.blobHeight / 2),
                    velocity: Point(x: velocity.width, y: velocity.height)
                )
            }
    }

    private func tap(count: Int) {
        if count == 2 {
            if !theme.still { lid = LidMotion.start(.wink) }
            model.toggleAssistant()
            return
        }
        guard count == 1, !justDragged else { return }
        model.toggleMenu()
    }

    private func follow(_ point: CGPoint?) {
        guard press == nil, !model.laneDragging else { return }
        guard let point else {
            model.setAwake(false)
            return
        }
        let origin = model.blobOrigin
        let cx = origin.x + g.blobWidth / 2
        let cy = origin.y + g.blobHeight / 2
        let dist = hypot(Double(point.x) - cx, Double(point.y) - cy)
        let now = Date.timeIntervalSinceReferenceDate
        let last = sample ?? PointerSample(point: point, time: now)
        let speed = hypot(Double(point.x - last.point.x), Double(point.y - last.point.y)) / max(SheetValues.pointerStep, now - last.time)
        sample = PointerSample(point: point, time: now)
        let fast = speed > Design.Motion.blobFlingSpeed && dist > Design.Size.blobFlingMinDistance && !model.awake
        model.setAwake(dist < Design.Size.blobWakeDistance && !fast)
        guard !theme.still else { return }
        let reach = dist < Design.Size.blobEyeFollowDistance ? min(1, dist / Design.Size.blobEyeFollowRamp) : 0
        let angle = atan2(Double(point.y) - cy, Double(point.x) - cx)
        eyes = CGSize(width: cos(angle) * Design.Size.blobEyeTravelX * reach, height: sin(angle) * Design.Size.blobEyeTravelY * reach)
    }

    private func blinkLoop() async {
        while !Task.isCancelled {
            let pause = Design.Duration.blobBlinkInterval + Double.random(in: 0..<Design.Duration.blobBlinkInterval)
            try? await Task.sleep(for: .seconds(pause))
            if !theme.still && (model.awake || model.mode != nil) { lid = LidMotion.start(.blink) }
        }
    }
}

struct BlobAnchor: Equatable {
    let up: Bool
    let right: Bool
}

struct PointerSample: Equatable {
    let point: CGPoint
    let time: TimeInterval
}

struct BlobPress {
    let start: CGPoint
    let origin: CGPoint
    var moved: Bool
    var history: [PointerSample]

    var velocity: CGSize {
        guard let first = history.first, let last = history.last else { return .zero }
        let span = max(SheetValues.releaseSpan, last.time - first.time)
        return CGSize(width: Double(last.point.x - first.point.x) / span, height: Double(last.point.y - first.point.y) / span)
    }
}

struct BlobStretch: Equatable {
    let angle: Double
    let amount: Double

    static let none = BlobStretch(angle: 0, amount: 0)

    init(angle: Double, amount: Double) {
        self.angle = angle
        self.amount = amount
    }

    init(history: [PointerSample]) {
        let pair = history.suffix(2)
        guard pair.count == 2, let a = pair.first, let b = pair.last else {
            self = .none
            return
        }
        let span = max(SheetValues.pointerStep, b.time - a.time)
        let vx = Double(b.point.x - a.point.x) / span
        let vy = Double(b.point.y - a.point.y) / span
        angle = atan2(vy, vx)
        amount = min(Design.Size.blobStretchMax, hypot(vx, vy) * SheetValues.stretchPerSpeed)
    }
}

struct BlobStretchEffect: GeometryEffect {
    var stretch: BlobStretch
    var squeeze: Double

    var animatableData: Double {
        get { squeeze }
        set { squeeze = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let center = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
        let scaleX = (1 + stretch.amount) * squeeze
        let scaleY = 1 / (1 + stretch.amount) * squeeze
        let form = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(CGAffineTransform(rotationAngle: -stretch.angle))
            .concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
            .concatenating(CGAffineTransform(rotationAngle: stretch.angle))
            .concatenating(center)
        return ProjectionTransform(form)
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
    let theme: Theme
    let ring: Bool
    let open: Bool
    let follow: CGSize
    let lid: LidMotion
    @State private var progress = 1.0

    var body: some View {
        let size = CGFloat(Design.Size.symbolSize)
        HStack(spacing: CGFloat(Design.Size.blobEyeGap)) {
            eye
            eye
        }
        .modifier(LidEffect(
            progress: progress,
            kind: lid.kind,
            scale: open ? 1 : SheetValues.lidRestScale,
            shift: open ? 0 : Design.Size.blobLidOffset
        ))
        .animation(theme.ease(Design.Duration.blobEyes), value: open)
        .offset(follow)
        .animation(nil, value: follow)
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.foreground, lineWidth: CGFloat(Design.Size.hairline)).opacity(ring ? 1 : 0))
        .onChange(of: lid) { _, next in run(next) }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: CGFloat(Design.Radius.stroke))
            .fill(.foreground)
            .frame(width: CGFloat(Design.Size.blobEyeWidth), height: CGFloat(Design.Size.blobEyeHeight))
    }

    private func run(_ motion: LidMotion) {
        guard let kind = motion.kind else { return }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0 }
        let animation: Animation = kind == .blink
            ? .linear(duration: Design.Duration.blobBlinkClose)
            : .timingCurve(Design.Easing.standard.x1, Design.Easing.standard.y1, Design.Easing.standard.x2, Design.Easing.standard.y2, duration: Design.Duration.blink)
        Task { @MainActor in
            withAnimation(animation) { progress = 1 }
        }
    }
}

struct LidEffect: ViewModifier, Animatable {
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

struct NoticeDot: View {
    let theme: Theme
    @State private var progress = 0.0

    var body: some View {
        let size = CGFloat(Design.Spacing.step4)
        Circle()
            .fill(.foreground)
            .frame(width: size, height: size)
            .modifier(PulseEffect(progress: progress))
            .onAppear {
                guard let pulse = theme.ease(Design.Duration.pulse) else { return }
                withAnimation(pulse.repeatForever(autoreverses: false)) { progress = 1 }
            }
    }
}

struct PulseEffect: ViewModifier, Animatable {
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

struct ThinkingOrb: View {
    let theme: Theme
    let size: Double
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: theme.still)) { context in
            orb(elapsed: theme.still ? 0 : context.date.timeIntervalSince(start))
        }
    }

    private func orb(elapsed: Double) -> some View {
        let side = CGFloat(size)
        let spot = side * CGFloat(SheetValues.orbSpot)
        let orbits = [Design.Duration.orbOrbitFirst, Design.Duration.orbOrbitSecond, Design.Duration.orbOrbitThird]
        let colors = [theme.mood(\.coral), theme.mood(\.apricot), theme.mood(\.rose)]
        let reach = theme.still ? 0 : Double(spot) * SheetValues.orbOrbit
        return ZStack {
            theme.design(\.orb)
            ForEach(0..<3, id: \.self) { index in
                let direction: Double = index == 1 ? -1 : 1
                let angle = 2 * Double.pi * elapsed / orbits[index] * direction
                Circle()
                    .fill(colors[index])
                    .frame(width: spot, height: spot)
                    .blur(radius: CGFloat(Design.Size.orbGlowBlur))
                    .blendMode(.screen)
                    .offset(x: CGFloat(cos(angle) * reach), y: CGFloat(sin(angle) * reach))
            }
            RadialGradient(
                colors: [theme.design(\.orbGloss), theme.design(\.orbGloss).opacity(0)],
                center: UnitPoint(x: SheetValues.orbGlossX, y: SheetValues.orbGlossY),
                startRadius: 0,
                endRadius: glossRadius(side)
            )
        }
        .compositingGroup()
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(theme.design(\.orbRim), lineWidth: CGFloat(Design.Size.hairline)))
    }

    private func glossRadius(_ side: CGFloat) -> CGFloat {
        let rx = 2.0.squareRoot() * max(SheetValues.orbGlossX, 1 - SheetValues.orbGlossX)
        let ry = 2.0.squareRoot() * max(SheetValues.orbGlossY, 1 - SheetValues.orbGlossY)
        return side * CGFloat(SheetValues.orbGlossStop * (rx + ry) / 2)
    }
}
