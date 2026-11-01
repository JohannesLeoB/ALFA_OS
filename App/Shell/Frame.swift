import AppKit
import Core
import Design
import Shell
import SwiftUI

struct Frame: View {
    let session: AppSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.locale) private var locale
    @State private var pointer: CGPoint?
    @State private var blobFrame = CGRect.zero

    private var desk: DeskState { session.desk }

    private var appearance: Appearance {
        Appearance(dark: scheme == .dark, still: reduce)
    }

    var body: some View {
        let appearance = appearance
        let measure = desk.measure
        let shut = session.lock.phase.shut
        ZStack {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    appearance.color(\.ground)
                    lanes(appearance)
                        .zIndex(Double(Tokens.Layer.lane))
                    handles(appearance)
                        .zIndex(Double(Tokens.Layer.handle))
                    SyncButton(session: session)
                        .offset(x: proxy.size.width - CGFloat(measure.margin + measure.blobWidth), y: CGFloat(measure.blobTop))
                        .zIndex(Double(Tokens.Layer.syncButton))
                    toasts(appearance)
                        .zIndex(Double(Tokens.Layer.toast))
                    Blob(session: session, pointer: pointer, frame: $blobFrame)
                        .zIndex(Double(Tokens.Layer.blob))
                }
                .dwellHintLayer()
                .eventMonitor([.leftMouseDown, .rightMouseDown]) { sample in
                    if let point = sample.local { session.act(at: Double(point.x)) }
                    return false
                }
                .coordinateSpace(name: Self.space)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clickAway(active: desk.mode != nil, inside: blobFrame) { desk.close() }
                .onContinuousHover(coordinateSpace: .named(Self.space)) { phase in
                    switch phase {
                    case .active(let point): pointer = point
                    case .ended: pointer = nil
                    }
                }
                .onAppear { desk.resize(BlobSize(width: proxy.size.width, height: proxy.size.height)) }
                .onChange(of: proxy.size) { _, size in desk.resize(BlobSize(width: size.width, height: size.height)) }
            }
            .underLock(shut)
            if shut {
                LockScreen(lock: session.lock, name: session.settings.profile.name, initials: session.lockInitials)
                    .zIndex(Double(Tokens.Layer.lockScreen))
            }
        }
        .eventMonitor([.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .mouseMoved]) { _ in
            session.lock.touch()
            return false
        }
        .onChange(of: session.settings.lockOn) { session.followLockSettings() }
        .onChange(of: session.settings.lockDelay) { session.followLockSettings() }
        .onChange(of: shut) { _, now in if now { desk.close() } }
        .onExitCommand { desk.close() }
        .onChange(of: desk.currentID, initial: true) { measureLabel(appearance) }
        .onChange(of: locale) { measureLabel(appearance) }
        .onChange(of: session.stackReport, initial: true) { _, report in desk.stack(empty: report, still: appearance.still) }
        .onChange(of: session.panes.mapValues(\.opened)) { old, new in
            for (id, count) in new where old[id] != count { desk.reveal(.trailing, in: id) }
        }
        .onChange(of: session.conversation.noteSerial) { session.toastArrived(.assistant) }
        .onChange(of: session.inbox.toast?.serial) { _, serial in if serial != nil { session.toastArrived(.mail) } }
        .onChange(of: session.settings.toastSerial) { session.toastArrived(.settings) }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .environment(\.appearance, appearance)
        .environment(\.session, session)
    }

    nonisolated static let space = "shell"

    private func measureLabel(_ appearance: Appearance) {
        desk.labelWidth = Typeface.width(appearance.string(desk.current?.titleKey ?? ""), size: Tokens.TextSize.body, weight: Tokens.Weight.medium)
    }

    private func laneAnimation(_ appearance: Appearance) -> Animation? {
        if desk.laneDragging { return nil }
        return desk.slowLane ? appearance.ease(Tokens.Transition.fold) : appearance.ease(Tokens.Duration.lane)
    }

    private func lanes(_ appearance: Appearance) -> some View {
        let widths = desk.widths
        let measure = desk.measure
        let height = CGFloat(measure.laneHeight(desk.window))
        let entry = desk.current
        let keys = [entry?.lanes.leadingKey ?? "", "", entry?.lanes.trailingKey ?? ""]
        let x = measure.lefts(widths)
        return ZStack(alignment: .topLeading) {
            ForEach(LaneKind.allCases, id: \.self) { lane in
                DeskLane(session: session, lane: lane, titleKey: keys[lane.index], size: CGSize(width: widths.width(lane), height: height))
                    .offset(x: CGFloat(x[lane.index]), y: CGFloat(measure.strip))
            }
        }
        .animation(laneAnimation(appearance), value: widths)
    }

    private func toasts(_ appearance: Appearance) -> some View {
        let widths = desk.widths
        let measure = desk.measure
        let lane = session.toastLane
        let width = CGFloat(widths.width(lane))
        return ZStack(alignment: .topLeading) {
            session.toast
                .frame(maxWidth: max(0, width - CGFloat(Tokens.Spacing.step16)))
                .padding(.bottom, CGFloat(Tokens.Size.footerHeight + Tokens.Spacing.step8))
                .frame(width: width, height: CGFloat(measure.laneHeight(desk.window)), alignment: .bottom)
                .offset(x: CGFloat(measure.lefts(widths)[lane.index]), y: CGFloat(measure.strip))
        }
        .animation(laneAnimation(appearance), value: widths)
    }

    private func handles(_ appearance: Appearance) -> some View {
        let widths = desk.widths
        let measure = desk.measure
        let height = CGFloat(measure.laneHeight(desk.window))
        let x = measure.lefts(widths)
        return ZStack(alignment: .topLeading) {
            LaneHandle(desk: desk, lane: .leading, height: height)
                .offset(x: CGFloat(x[0] + widths.leading), y: CGFloat(measure.strip))
            LaneHandle(desk: desk, lane: .trailing, height: height)
                .offset(x: CGFloat(x[1] + widths.center), y: CGFloat(measure.strip))
        }
        .animation(laneAnimation(appearance), value: widths)
    }
}

struct DeskLane: View {
    let session: AppSession
    let lane: LaneKind
    let titleKey: String
    let size: CGSize
    @Environment(\.appearance) private var appearance

    private var desk: DeskState { session.desk }

    private var pane: (any Pane)? { session.panes[desk.currentID] }

    private var title: PaneTitle { pane?.title(lane) ?? .key(titleKey) }

    private var name: PaneTitle { pane?.name(lane) ?? .key(titleKey) }

    private var ownsHead: Bool { pane?.ownsHead(lane) ?? false }

    var body: some View {
        let measure = desk.measure
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.lane))
        let folded = Double(size.width) <= measure.laneFolded
        let strip = Double(size.width) < measure.foldAt
        let inner = max(size.width, CGFloat(desk.minimum[lane.index]))
        let fade = appearance.ease(Tokens.Duration.hover)
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { if folded { desk.openStrip(lane) } }
                .simultaneousGesture(TapGesture(count: 2).onEnded { desk.restLane(lane) })
                .pointerStyle(folded ? PointerStyle.link : nil)
            marks
                .frame(width: size.width, height: size.height, alignment: .top)
                .opacity(strip ? 1 : 0)
                .allowsHitTesting(strip)
                .accessibilityHidden(!strip)
                .animation(fade, value: strip)
            VStack(spacing: 0) {
                if !ownsHead { header }
                content
            }
            .frame(width: inner, height: size.height, alignment: .topLeading)
            .opacity(strip ? 0 : 1)
            .allowsHitTesting(!strip)
            .accessibilityHidden(strip)
            .animation(fade, value: strip)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(appearance.color(\.lane))
        .clipShape(shape)
        .shadowLayers(shape, \.lane)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title.text(appearance))
    }

    @ViewBuilder
    private var marks: some View {
        if let marks = pane?.marks(lane, height: Double(size.height)) { marks }
    }

    @ViewBuilder
    private var content: some View {
        if let pane { pane.content(lane) } else { Color.clear.frame(maxHeight: .infinity) }
    }

    private var header: some View {
        LaneHead(lane: lane) {
            if !(pane?.hidesTitle(lane) ?? false) { HeaderTitle(text: title.text(appearance)) }
            Spacer(minLength: 0)
            tools
        }
    }

    @ViewBuilder
    private var tools: some View {
        let open = desk.widths.all.filter { $0 > desk.measure.laneFolded }.count
        let name = self.name.string(appearance)
        if lane == .center {
            let maxed = desk.laneMode(desk.currentID).maximized == .center
            SymbolButton(help: maxed ? appearance.string("settings.account.back") : appearance.format("mail.grow.named", name),
                         glyph: maxed ? .shrink : .expand, pressed: false) { desk.toggleMaximize(.center) }
        }
        if open > 1 {
            SymbolButton(help: appearance.format("mail.fold.named", name), glyph: .minus, pressed: lane != .center) { desk.toggleFold(lane) }
        }
    }
}

struct LaneHandle: View {
    let desk: DeskState
    let lane: LaneKind
    let height: CGFloat
    @Environment(\.appearance) private var appearance
    @GestureState private var pressing = false
    @State private var hovering = false
    @FocusState private var focused: Bool
    @State private var pointerFocus = false

    private var dragging: Bool { desk.draggedLane == lane }

    private var active: Bool { hovering || dragging }

    var body: some View {
        let width = desk.widths.width(lane)
        let value = appearance.format("lane.handle.value", String(Int(width.rounded())))
        let thick = CGFloat(active ? Tokens.Size.handleThicknessActive : Tokens.Size.hairline)
        let long = CGFloat(active ? Tokens.Size.handleLengthActive : Tokens.Size.handleLength)
        let tone = appearance.color(active ? \.ink : \.inkTertiary)
        let plain = appearance.ease(Tokens.Duration.short, SheetValues.cssEase)
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.stroke))
                .animation(plain) { $0.foregroundStyle(tone) }
                .animation(plain) { $0.frame(width: thick) }
                .animation(appearance.ease(Tokens.Duration.short)) { $0.frame(height: long) }
        }
        .frame(width: CGFloat(Tokens.Size.gutter), height: height)
        .overlay(alignment: .top) {
            if dragging {
                Text(verbatim: value)
                    .font(.face(Tokens.TextSize.small))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
                    .frame(height: CGFloat(Tokens.Spacing.step24))
                    .foregroundStyle(appearance.color(\.onInverse))
                    .background(Capsule().fill(appearance.color(\.inverse)))
                    .padding(.top, CGFloat(Tokens.Spacing.step12))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if focused && !pointerFocus {
                Rectangle()
                    .strokeBorder(appearance.color(\.focus), lineWidth: CGFloat(Tokens.Size.focusRingWidth))
                    .padding(-CGFloat(Tokens.Size.focusRingOffset + Tokens.Size.focusRingWidth))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .pointerStyle(.columnResize)
        .onHover { hovering = $0 }
        .focusable()
        .focused($focused)
        .onChange(of: focused) { _, now in pointerFocus = now && NSApp.currentEvent?.type != .keyDown }
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .return]) { press in
            pointerFocus = false
            return key(press)
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .updating($pressing) { _, state, _ in state = true }
                .onChanged { drag in
                    pointerFocus = true
                    desk.dragLane(lane, translation: Double(drag.translation.width))
                }
        )
        .simultaneousGesture(TapGesture(count: 2).onEnded { desk.resetLane() })
        .onChange(of: pressing) { _, now in if !now { desk.endLaneDrag() } }
        .onDisappear { desk.endLaneDrag() }
        .accessibilityElement()
        .accessibilityLabel(appearance.text(lane == .leading ? "lane.handle.leading" : "lane.handle.trailing"))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
        .dwellHint("shell.handle.down.tooltip", focused: focused && !pointerFocus)
    }

    private func key(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .return {
            desk.resetLane()
            return .handled
        }
        let size = press.modifiers.contains(.shift) ? SheetValues.laneShiftStep : desk.measure.laneFolded
        let direction: Double = press.key == .leftArrow ? -1 : 1
        desk.stepLane(lane, by: size * direction * (lane == .leading ? 1 : -1))
        return .handled
    }

    private func step(by sign: Double) {
        desk.stepLane(lane, by: desk.measure.laneFolded * sign)
    }
}

enum PaneTitle {
    case key(String)
    case verbatim(String)

    func text(_ appearance: Appearance) -> Text {
        switch self {
        case .key(let key): appearance.text(key)
        case .verbatim(let value): Text(verbatim: value)
        }
    }

    func string(_ appearance: Appearance) -> String {
        switch self {
        case .key(let key): appearance.string(key)
        case .verbatim(let value): value
        }
    }
}

@MainActor
protocol Pane {
    var stackEmpty: Bool { get }
    var badge: Int { get }
    var opened: Int { get }
    var limits: AreaLimits { get }
    var toast: AnyView? { get }
    func ownsHead(_ lane: LaneKind) -> Bool
    func title(_ lane: LaneKind) -> PaneTitle?
    func name(_ lane: LaneKind) -> PaneTitle?
    func hidesTitle(_ lane: LaneKind) -> Bool
    func marks(_ lane: LaneKind, height: Double) -> AnyView?
    func content(_ lane: LaneKind) -> AnyView
}

extension Pane {
    var stackEmpty: Bool { false }

    var badge: Int { 0 }

    var opened: Int { 0 }

    var limits: AreaLimits { AreaLimits() }

    var toast: AnyView? { nil }

    func ownsHead(_ lane: LaneKind) -> Bool { false }

    func title(_ lane: LaneKind) -> PaneTitle? { nil }

    func name(_ lane: LaneKind) -> PaneTitle? { title(lane) }

    func hidesTitle(_ lane: LaneKind) -> Bool { false }

    func marks(_ lane: LaneKind, height: Double) -> AnyView? { nil }
}

struct SyncButton: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var turn = 0.0

    var body: some View {
        let failed = session.syncFailed
        let profile = session.settings.profile
        let face = Initials.avatar(code: profile.code, name: profile.name)
        let title = session.syncing ? "settings.link.working" : failed ? "sync.failed" : "sync.fresh"
        let ring = CGFloat(Tokens.Size.symbolSize)
        let line = CGFloat(Tokens.Size.hairline)
        Button(action: run) {
            ZStack {
                Text(verbatim: face)
                    .typeStyle(Tokens.TextStyle.markSmall)
                Circle()
                    .strokeBorder(.foreground, lineWidth: line)
                    .opacity(Tokens.Opacity.ringOnColor)
                Circle()
                    .inset(by: line / 2)
                    .trim(from: 0, to: failed ? CGFloat(SheetValues.syncErrorArc) : 1)
                    .stroke(failed ? AnyShapeStyle(appearance.color(\.signal)) : AnyShapeStyle(.foreground), lineWidth: line)
                    .rotationEffect(.degrees(SheetValues.syncArcStart + turn))
            }
            .frame(width: ring, height: ring)
            .padding(.horizontal, CGFloat(Tokens.Spacing.blobInset))
            .frame(width: CGFloat(Tokens.Spacing.step56), height: CGFloat(Tokens.Spacing.step40), alignment: .trailing)
            .foregroundStyle(appearance.color(\.onInverse))
            .background(Capsule().fill(appearance.color(\.inverse)))
            .overlay(alignment: .topLeading) {
                if failed {
                    Circle()
                        .fill(appearance.color(\.signal))
                        .frame(width: CGFloat(Tokens.Spacing.statusDot), height: CGFloat(Tokens.Spacing.statusDot))
                        .padding(.top, CGFloat(Tokens.Spacing.blobInset))
                        .padding(.leading, CGFloat(Tokens.Spacing.step12))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadowLayers(Capsule())
        .dwellHint(title)
        .accessibilityLabel(appearance.text(title))
    }

    private func run() {
        guard !session.syncing else { return }
        if let spin = appearance.ease(Tokens.Duration.syncSpin) {
            withAnimation(spin) { turn += SheetValues.syncSweep }
        }
        Task { await session.sync() }
    }
}
