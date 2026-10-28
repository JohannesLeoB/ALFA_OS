import AppKit
import Design
import Shell
import SwiftUI

struct Frame: View {
    let session: AppSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var pointer: CGPoint?
    @State private var blobFrame = CGRect.zero

    private var desk: DeskState { session.desk }

    private var appearance: Appearance {
        Appearance(dark: scheme == .dark, still: reduce)
    }

    var body: some View {
        let appearance = appearance
        let measure = desk.measure
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
        .onExitCommand { desk.close() }
        .onChange(of: desk.currentID, initial: true) {
            desk.labelWidth = Typeface.width(appearance.string(desk.current?.titleKey ?? ""), size: Tokens.TextSize.body, weight: Tokens.Weight.medium)
        }
        .onChange(of: session.stackEmpty, initial: true) { _, empty in desk.stack(empty: empty, still: appearance.still) }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .environment(\.appearance, appearance)
        .environment(\.session, session)
    }

    nonisolated static let space = "shell"

    private func laneAnimation(_ appearance: Appearance) -> Animation? {
        if desk.laneDragging { return nil }
        return desk.slowLane ? appearance.ease(Tokens.Transition.fold) : appearance.ease(Tokens.Duration.lane)
    }

    private func lefts() -> [Double] {
        let w = desk.widths
        let m = desk.measure
        return [m.margin, m.margin + w.leading + m.gap, m.margin + w.leading + w.center + 2 * m.gap]
    }

    private func lanes(_ appearance: Appearance) -> some View {
        let widths = desk.widths
        let measure = desk.measure
        let height = CGFloat(measure.laneHeight(desk.window))
        let entry = desk.current
        let keys = [entry?.lanes.leadingKey ?? "", "", entry?.lanes.trailingKey ?? ""]
        let x = lefts()
        return ZStack(alignment: .topLeading) {
            ForEach(LaneKind.allCases, id: \.self) { lane in
                Lane(session: session, lane: lane, titleKey: keys[lane.index], size: CGSize(width: widths.width(lane), height: height))
                    .offset(x: CGFloat(x[lane.index]), y: CGFloat(measure.strip))
            }
        }
        .animation(laneAnimation(appearance), value: widths)
    }

    private func toasts(_ appearance: Appearance) -> some View {
        let widths = desk.widths
        let measure = desk.measure
        let height = CGFloat(measure.laneHeight(desk.window))
        let pane = session.panes[desk.currentID]
        let x = lefts()
        return ZStack(alignment: .topLeading) {
            ForEach(LaneKind.allCases, id: \.self) { lane in
                if let toast = pane?.toast(lane) {
                    toast
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.bottom, CGFloat(Tokens.Size.footerHeight + Tokens.Spacing.step8))
                        .frame(width: CGFloat(widths.width(lane)), height: height, alignment: .bottom)
                        .offset(x: CGFloat(x[lane.index]), y: CGFloat(measure.strip))
                }
            }
        }
        .animation(laneAnimation(appearance), value: widths)
    }

    private func handles(_ appearance: Appearance) -> some View {
        let widths = desk.widths
        let measure = desk.measure
        let height = CGFloat(measure.laneHeight(desk.window))
        let x = lefts()
        return ZStack(alignment: .topLeading) {
            LaneHandle(desk: desk, lane: .leading, height: height)
                .dwellHint("shell.handle.down.tooltip")
                .offset(x: CGFloat(x[0] + widths.leading), y: CGFloat(measure.strip))
            LaneHandle(desk: desk, lane: .trailing, height: height)
                .dwellHint("shell.handle.down.tooltip")
                .offset(x: CGFloat(x[1] + widths.center), y: CGFloat(measure.strip))
        }
        .animation(laneAnimation(appearance), value: widths)
    }
}
