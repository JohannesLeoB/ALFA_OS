import DrawingKit
import ShellCore
import SwiftUI

struct ShellScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable var model: DrawsModel
    @State private var lanes = LaneState(rest: Design.Size.laneRestWidth)
    @State private var dragStart: [Double]?
    @State private var menu = false
    private let geometry = ShellGeometry()

    var body: some View {
        let style = Style(dark: scheme == .dark)
        GeometryReader { proxy in
            let w = Double(proxy.size.width), h = Double(proxy.size.height)
            let m = Design.Size.edge, gap = Design.Size.gutter
            let top = Design.Size.safeAreaTop + m
            let laneTop = top + Design.Size.blobHeight + gap
            let laneHeight = max(0, h - laneTop - m)
            let widths = LaneLayout.widths(windowWidth: w, state: lanes, geometry: geometry, rules: rules)
            let lefts = [m, m + widths.leading + gap, m + widths.leading + widths.center + 2 * gap]
            ZStack(alignment: .topLeading) {
                style.color(\.ground)
                ForEach(Lane.allCases, id: \.self) { lane in
                    LaneBox(width: widths.width(lane), height: laneHeight) { content(lane) }
                        .offset(x: CGFloat(lefts[lane.index]), y: CGFloat(laneTop))
                }
                ForEach([Lane.leading, Lane.trailing], id: \.self) { lane in
                    Handle(
                        height: laneHeight,
                        width: widths.width(lane),
                        sign: lane == .leading ? 1 : -1,
                        drag: { drag(lane, proposed: $0, current: widths) },
                        end: { dragStart = nil },
                        step: { drag(lane, proposed: widths.width(lane) + $0, current: widths, keep: true) },
                        reset: { lanes = LaneLayout.reset(rest: geometry.laneRest) }
                    )
                    .offset(x: CGFloat(lefts[lane.index] + widths.width(lane)), y: CGFloat(laneTop))
                }
                Blob(open: $menu, choose: choose)
                    .offset(x: CGFloat(m), y: CGFloat(top))
            }
            .animation(style.ease(Design.Duration.lane), value: widths)
        }
        .environment(\.style, style)
        .font(style.font())
        .ignoresSafeArea()
        .navigationTitle(model.windowTitle)
        .dropDestination(for: URL.self) { urls, _ in
            model.drop(urls)
        }
        .onAppear { model.start() }
    }

    private var rules: AreaRules { AreaRules(minimum: geometry.minimum, yield: [Lane.trailing.index, Lane.leading.index, Lane.center.index]) }

    private func drag(_ lane: Lane, proposed: Double, current: LaneWidths, keep: Bool = false) {
        let start = keep ? current.all : (dragStart ?? current.all)
        if !keep { dragStart = start }
        lanes = LaneLayout.drag(lane: lane, proposed: proposed, start: start, state: lanes, geometry: geometry, rules: rules)
    }

    private func choose(_ key: String) {
        menu = false
        switch key {
        case "draws.area.sheet": lanes = LaneLayout.toggleMaximize(lane: .center, state: lanes)
        case "draws.area.packs": open(.leading)
        case "draws.area.views", "draws.area.export":
            open(.trailing)
            model.tab = key == "draws.area.views" ? .view : .export
        case "draws.area.claude":
            if lanes.maximized != .center { lanes.maximized = nil }
            model.assistant = true
        default: break
        }
    }

    private func open(_ lane: Lane) {
        lanes.maximized = nil
        lanes.folded[lane.index] = false
        lanes.preferred[lane.index] = geometry.laneRest
    }

    private func grow(_ lane: Lane) -> Binding<Bool> {
        Binding(get: { lanes.maximized == lane }, set: { lanes.maximized = $0 ? lane : nil })
    }

    @ViewBuilder
    private func content(_ lane: Lane) -> some View {
        switch lane {
        case .leading: ProjectLane(model: model)
        case .center: SheetLane(model: model, maximized: grow(.center))
        case .trailing: InspectorLane(model: model, maximized: grow(.trailing))
        }
    }
}

struct LaneBox<Content: View>: View {
    @Environment(\.style) private var style
    let width: Double
    let height: Double
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.lane))
        let strip = width < Design.Size.foldThreshold
        content
            .frame(width: CGFloat(max(width, Design.Size.laneMinimumLeft)), height: CGFloat(height), alignment: .topLeading)
            .opacity(strip ? 0 : 1)
            .allowsHitTesting(!strip)
            .animation(style.ease(Design.Duration.hover), value: strip)
            .frame(width: CGFloat(width), height: CGFloat(height), alignment: .topLeading)
            .background(style.color(\.lane))
            .clipShape(shape)
            .shadowed(style, style.shadow(\.lane), shape)
    }
}

struct Handle: View {
    @Environment(\.style) private var style
    let height: Double
    let width: Double
    let sign: Double
    let drag: (Double) -> Void
    let end: () -> Void
    let step: (Double) -> Void
    let reset: () -> Void
    @State private var startWidth: Double?
    @State private var hovering = false
    @FocusState private var focused: Bool
    @State private var pointerFocus = false

    var body: some View {
        let active = hovering || startWidth != nil
        let thick = CGFloat(active ? Design.Size.handleThicknessActive : Design.Size.hairline)
        let long = CGFloat(active ? Design.Size.handleLengthActive : Design.Size.handleLength)
        let tone = style.color(active ? \.ink : \.inkTertiary)
        let plain = style.ease(Design.Duration.short, SheetValues.gripCurve)
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat(Design.Radius.stroke))
                .animation(plain) { $0.foregroundStyle(tone) }
                .animation(plain) { $0.frame(width: thick) }
                .animation(style.ease(Design.Duration.short)) { $0.frame(height: long) }
        }
        .frame(width: CGFloat(Design.Size.gutter), height: CGFloat(height))
        .overlay(alignment: .top) {
            if startWidth != nil {
                Text(verbatim: String(format: word("lane.handle.value"), Int(width.rounded())))
                    .font(style.font(Design.TextSize.small))
                    .monospacedDigit()
                    .fixedSize()
                    .padding(.horizontal, CGFloat(Design.Size.menuRowPadding))
                    .frame(height: CGFloat(Design.Size.chipHeight))
                    .foregroundStyle(style.color(\.onInverse))
                    .background(Capsule().fill(style.color(\.inverse)))
                    .padding(.top, CGFloat(Design.Spacing.step12))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if focused && !pointerFocus {
                Rectangle()
                    .strokeBorder(style.color(\.focus), lineWidth: CGFloat(Design.Size.focusRingWidth))
                    .padding(-CGFloat(Design.Size.focusRingOffset + Design.Size.focusRingWidth))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .pointerStyle(.columnResize)
        .onHover { hovering = $0 }
        .focusable()
        .focused($focused)
        .onChange(of: focused) { _, now in if !now { pointerFocus = false } }
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .return]) { press in
            pointerFocus = false
            return key(press)
        }
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                pointerFocus = true
                let start = startWidth ?? width
                startWidth = start
                drag(start + Double(value.translation.width) * sign)
            }
            .onEnded { _ in
                startWidth = nil
                end()
            })
        .simultaneousGesture(TapGesture(count: 2).onEnded { reset() })
    }

    private func key(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .return {
            reset()
            return .handled
        }
        let amount = press.modifiers.contains(.shift) ? SheetValues.laneShiftStep : Design.Size.foldedWidth
        step(amount * (press.key == .leftArrow ? -1 : 1) * sign)
        return .handled
    }
}

struct Blob: View {
    @Environment(\.style) private var style
    @Binding var open: Bool
    let choose: (String) -> Void
    @State private var hot: String?

    static let rows = ["draws.area.sheet", "draws.area.packs", "draws.area.views", "draws.area.claude", "draws.area.export"]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.blob))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                face
            }
            .padding(.horizontal, CGFloat(Design.Spacing.blobInset))
            .frame(height: CGFloat(Design.Size.blobHeight))
            .contentShape(Rectangle())
            .onTapGesture { open.toggle() }
            if open {
                Rectangle().fill(style.color(\.inverseLine))
                    .frame(height: CGFloat(Design.Size.hairline))
                    .padding(.horizontal, CGFloat(Design.Size.menuSeparatorInset))
                    .padding(.bottom, CGFloat(Design.Size.menuEdge))
                ForEach(Self.rows, id: \.self) { key in
                    say(key)
                        .foregroundStyle(style.color(\.onInverse))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, CGFloat(Design.Size.menuRowPadding))
                        .frame(height: CGFloat(Design.Size.menuRowHeight))
                        .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
                            .fill(hot == key ? style.color(\.inverseHot) : Color.clear))
                        .contentShape(Rectangle())
                        .onHover { hot = $0 ? key : nil }
                        .onTapGesture { choose(key) }
                }
                .padding(.horizontal, CGFloat(Design.Size.menuEdge))
                Spacer().frame(height: CGFloat(Design.Size.menuEdge))
            }
        }
        .frame(width: CGFloat(open ? Design.Size.laneRestWidth : Design.Size.blobWidth), alignment: .leading)
        .background(shape.fill(style.color(\.inverse)))
        .shadowed(style, style.shadow(\.floating), shape)
        .animation(style.ease(Design.Duration.blobWidth), value: open)
        .onExitCommand { open = false }
    }

    private var face: some View {
        HStack(spacing: CGFloat(Design.Size.blobEyeGap)) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CGFloat(Design.Radius.stroke))
                    .fill(style.color(\.onInverse))
                    .frame(width: CGFloat(Design.Size.blobEyeWidth), height: CGFloat(Design.Size.blobEyeHeight))
            }
        }
        .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
        .overlay(Circle().strokeBorder(style.color(\.onInverse), lineWidth: CGFloat(Design.Size.hairline)))
    }
}
