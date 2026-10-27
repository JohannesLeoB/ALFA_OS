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
        let flight = appearance.still || held != nil || place != anchor ? nil : appearance.ease(Tokens.Duration.blobFlight, Tokens.Easing.blobFlight)

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
        let dot = !open && !docked && session.attention
        return HStack(spacing: 0) {
            if orbFace {
                ThinkingOrb(size: Tokens.Size.symbolSize)
            } else {
                BlobEyes(ring: !docked, open: desk.awake || open || pressing, follow: eyes, lid: lid)
            }
            appearance.text(orbFace ? "assistant.title" : desk.current?.titleKey ?? "")
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
        .dwellHint("shell.blobFace.tooltip")
        .blobPress(desk: desk, held: $held, stretch: $stretch, squeezed: $squeezed, pressing: $pressing, tap: tap)
        .pointerStyle(held != nil ? .grabActive : open ? .default : .grabIdle)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(appearance.text(desk.current?.titleKey ?? ""))
    }

    @ViewBuilder
    private func content(up: Bool) -> some View {
        if desk.menuOpen {
            BlobMenu(session: session, up: up)
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
