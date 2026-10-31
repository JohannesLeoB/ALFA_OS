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
