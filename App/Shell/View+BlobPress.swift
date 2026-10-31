import AppKit
import Design
import Shell
import SwiftUI

private struct BlobPress {
    let start: CGPoint
    let origin: CGPoint
    var moved: Bool
    var history: [PointerSample]

    var velocity: BlobPoint {
        guard let first = history.first, let last = history.last else { return BlobPoint(x: 0, y: 0) }
        let span = max(SheetValues.releaseSpan, last.time - first.time)
        return BlobPoint(x: (last.point.x - first.point.x) / span, y: (last.point.y - first.point.y) / span)
    }
}

private struct BlobPressing: ViewModifier {
    let desk: DeskState
    @Binding var held: CGPoint?
    @Binding var stretch: BlobStretch
    @Binding var squeezed: Bool
    @Binding var pressing: Bool
    let tap: (Int) -> Void
    @Environment(\.appearance) private var appearance
    @Environment(\.appLocked) private var locked
    @State private var press: BlobPress?
    @State private var justDragged = false

    func body(content: Content) -> some View {
        content
            .gesture(drag)
            .onChange(of: locked) { _, now in if now { finish(ended: false) } }
            .onDisappear { finish(ended: false) }
    }

    private func sample(_ value: DragGesture.Value, _ now: Double) -> PointerSample {
        PointerSample(point: BlobPoint(x: Double(value.location.x), y: Double(value.location.y)), time: now)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Frame.space))
            .onChanged { value in
                let now = Date.timeIntervalSinceReferenceDate
                if press == nil {
                    let origin = CGPoint(x: desk.blobOrigin.x, y: desk.blobOrigin.y)
                    press = BlobPress(start: value.startLocation, origin: origin, moved: false, history: [sample(value, now)])
                    pressing = true
                    if !appearance.still { squeezed = true }
                }
                guard var current = press else { return }
                let dx = value.location.x - current.start.x
                let dy = value.location.y - current.start.y
                if !current.moved && hypot(dx, dy) < Tokens.Size.blobDragThreshold { return }
                if !current.moved {
                    current.moved = true
                    desk.beginBlobDrag()
                }
                current.history = Array((current.history + [sample(value, now)]).suffix(SheetValues.releaseSamples))
                press = current
                held = CGPoint(x: current.origin.x + dx, y: current.origin.y + dy)
                squeezed = false
                stretch = appearance.still ? .none : BlobStretch(history: current.history)
            }
            .onEnded { _ in finish(ended: true) }
    }

    private func finish(ended: Bool) {
        squeezed = false
        stretch = .none
        guard let current = press else { return }
        press = nil
        pressing = false
        guard current.moved, let spot = held else {
            guard ended else { return }
            let count = NSApp.currentEvent?.clickCount ?? 1
            if count == 2 || !justDragged { tap(count) }
            return
        }
        justDragged = true
        Task {
            try? await Task.sleep(for: .seconds(Tokens.Duration.clickGuard))
            justDragged = false
        }
        held = nil
        desk.dropBlob(
            center: BlobPoint(x: Double(spot.x) + desk.measure.blobWidth / 2, y: Double(spot.y) + desk.measure.blobHeight / 2),
            velocity: ended ? current.velocity : BlobPoint(x: 0, y: 0)
        )
    }
}

extension View {
    func blobPress(desk: DeskState, held: Binding<CGPoint?>, stretch: Binding<BlobStretch>, squeezed: Binding<Bool>,
                   pressing: Binding<Bool>, tap: @escaping (Int) -> Void) -> some View {
        modifier(BlobPressing(desk: desk, held: held, stretch: stretch, squeezed: squeezed, pressing: pressing, tap: tap))
    }
}

private struct BlobStretchEffect: GeometryEffect {
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

extension View {
    func blobStretch(_ stretch: BlobStretch, squeeze: Double) -> some View {
        modifier(BlobStretchEffect(stretch: stretch, squeeze: squeeze))
    }
}
