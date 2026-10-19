import AppKit
import ShellCore
import SwiftUI

struct ShellView: View {
    let resources: ShellResources
    let bundle: Bundle
    @Bindable var model: ShellModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.appHost) private var host
    @State private var pointer: CGPoint?
    @State private var blobFrame = CGRect.zero

    private var theme: Theme {
        Theme(geometry: resources.geometry, dark: scheme == .dark, still: reduce, bundle: bundle)
    }

    var body: some View {
        let theme = theme
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                theme.design(\.ground)
                lanes(theme)
                handles(theme)
                SyncButton(theme: theme, host: host)
                    .offset(x: proxy.size.width - CGFloat(theme.geometry.margin + theme.geometry.blobWidth), y: CGFloat(theme.geometry.blobTop))
                BlobView(theme: theme, model: model, host: host, pointer: pointer, frame: $blobFrame)
            }
            .coordinateSpace(name: "shell")
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .background(ClickAway(active: model.mode != nil, inside: blobFrame) { model.close() })
            .onContinuousHover(coordinateSpace: .named("shell")) { phase in
                switch phase {
                case .active(let point): pointer = point
                case .ended: pointer = nil
                }
            }
            .onAppear { model.resize(Size(width: proxy.size.width, height: proxy.size.height)) }
            .onChange(of: proxy.size) { _, size in model.resize(Size(width: size.width, height: size.height)) }
        }
        .onExitCommand { model.close() }
        .onChange(of: model.currentID, initial: true) {
            model.labelWidth = Typeface.width(theme.string(model.current?.titleKey ?? ""), size: Design.TextSize.body, weight: Design.Weight.medium)
        }
        .onChange(of: stackEmpty, initial: true) { _, empty in model.stack(empty: empty, still: theme.still) }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
    }

    private var stackEmpty: Bool {
        model.currentID == "mail" && (host?.stackEmpty ?? true)
    }

    private func laneAnimation(_ theme: Theme) -> Animation? {
        if model.laneDragging { return nil }
        return model.slowLane ? theme.ease(Design.Duration.fold, Design.Easing.fold) : theme.ease(Design.Duration.lane)
    }

    private func lefts(_ theme: Theme) -> [Double] {
        let w = model.widths
        let g = theme.geometry
        return [g.margin, g.margin + w.leading + g.gap, g.margin + w.leading + w.center + 2 * g.gap]
    }

    private func lanes(_ theme: Theme) -> some View {
        let widths = model.widths
        let g = theme.geometry
        let height = CGFloat(g.laneHeight(model.window))
        let entry = model.current
        let keys = [entry?.lanes.leadingKey ?? "", entry?.lanes.centerKey ?? "", entry?.lanes.trailingKey ?? ""]
        let x = lefts(theme)
        return ZStack(alignment: .topLeading) {
            ForEach(Lane.allCases, id: \.self) { lane in
                LaneView(theme: theme, model: model, lane: lane, titleKey: keys[lane.index], size: CGSize(width: widths.width(lane), height: height))
                    .offset(x: CGFloat(x[lane.index]), y: CGFloat(g.strip))
            }
        }
        .animation(laneAnimation(theme), value: widths)
    }

    private func handles(_ theme: Theme) -> some View {
        let widths = model.widths
        let g = theme.geometry
        let height = CGFloat(g.laneHeight(model.window))
        let x = lefts(theme)
        return ZStack(alignment: .topLeading) {
            HandleView(theme: theme, model: model, lane: .leading, height: height)
                .offset(x: CGFloat(x[0] + widths.leading), y: CGFloat(g.strip))
            HandleView(theme: theme, model: model, lane: .trailing, height: height)
                .offset(x: CGFloat(x[1] + widths.center), y: CGFloat(g.strip))
        }
        .animation(laneAnimation(theme), value: widths)
    }
}

struct SyncButton: View {
    let theme: Theme
    let host: AppHost?
    @State private var turn = 0.0

    var body: some View {
        let failed = host?.syncFailed ?? false
        let title = host?.syncing == true ? "sync.running" : failed ? "sync.failed" : "sync.fresh"
        let ring = CGFloat(Design.Size.symbolSize)
        let line = CGFloat(Design.Size.hairline)
        Button(action: run) {
            ZStack {
                theme.text("person.initials")
                    .font(theme.font(Design.TextSize.blobFace, weight: Design.Weight.medium))
                    .tracking(CGFloat(SheetValues.initialsTracking * Design.TextSize.blobFace))
                Circle()
                    .strokeBorder(.foreground, lineWidth: line)
                    .opacity(Design.Opacity.ringOnColor)
                Circle()
                    .inset(by: line / 2)
                    .trim(from: 0, to: failed ? CGFloat(SheetValues.syncErrorArc) : 1)
                    .stroke(failed ? AnyShapeStyle(theme.design(\.signal)) : AnyShapeStyle(.foreground), lineWidth: line)
                    .rotationEffect(.degrees(-90 + turn))
            }
            .frame(width: ring, height: ring)
            .padding(.horizontal, CGFloat(Design.Spacing.blobInset))
            .frame(width: CGFloat(Design.Size.blobWidth), height: CGFloat(Design.Size.blobHeight), alignment: .trailing)
            .foregroundStyle(theme.design(\.onInverse))
            .background(Capsule().fill(theme.design(\.inverse)))
            .overlay(alignment: .topLeading) {
                if failed {
                    Circle()
                        .fill(theme.design(\.signal))
                        .frame(width: CGFloat(Design.Spacing.statusDot), height: CGFloat(Design.Spacing.statusDot))
                        .padding(.top, CGFloat(Design.Spacing.blobInset))
                        .padding(.leading, CGFloat(Design.Spacing.step12))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .themeShadow(theme, layers: theme.designShadow(\.floating), shape: Capsule())
        .help(theme.string(title))
        .accessibilityLabel(theme.text(title))
    }

    private func run() {
        guard let host, !host.syncing else { return }
        if let spin = theme.ease(Design.Duration.syncSpin) {
            withAnimation(spin) { turn += 360 * SheetValues.syncTurns }
        }
        Task { await host.sync() }
    }
}

struct ClickAway: NSViewRepresentable {
    let active: Bool
    let inside: CGRect
    let away: () -> Void

    func makeNSView(context: Context) -> ClickAwayView {
        ClickAwayView()
    }

    func updateNSView(_ view: ClickAwayView, context: Context) {
        view.inside = inside
        view.away = away
        view.listen(active)
    }

    static func dismantleNSView(_ view: ClickAwayView, coordinator: ()) {
        view.listen(false)
    }
}

final class ClickAwayView: NSView {
    var inside = CGRect.zero
    var away: () -> Void = {}
    private var monitor: Any?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func listen(_ on: Bool) {
        if on, monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                MainActor.assumeIsolated { self?.check(event) }
                return event
            }
        } else if !on, let current = monitor {
            NSEvent.removeMonitor(current)
            monitor = nil
        }
    }

    private func check(_ event: NSEvent) {
        guard event.window === window else { return }
        let point = convert(event.locationInWindow, from: nil)
        if !inside.contains(point) { away() }
    }
}
