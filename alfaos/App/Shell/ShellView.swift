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
        switch model.currentID {
        case "mail": host?.stackEmpty ?? true
        case "settings": SettingsShared.board.cards.isEmpty
        default: false
        }
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
        let keys = [entry?.lanes.leadingKey ?? "", "", entry?.lanes.trailingKey ?? ""]
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
