import DrawingKit
import ShellCore
import SwiftUI

enum Lane: Int, CaseIterable { case leading, center, trailing }

struct ShellScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable var model: DrawsModel
    @State private var leading = Design.Size.laneRestWidth
    @State private var trailing = Design.Size.laneRestWidth
    @State private var big: Lane?
    @State private var menu = false

    var body: some View {
        let style = Style(dark: scheme == .dark)
        GeometryReader { proxy in
            let w = Double(proxy.size.width), h = Double(proxy.size.height)
            let m = Design.Size.edge, gap = Design.Size.gutter
            let top = Design.Size.safeAreaTop + m
            let laneTop = top + Design.Size.blobHeight + gap
            let laneHeight = max(0, h - laneTop - m)
            let widths = widths(available: w - 2 * m - 2 * gap)
            let lefts = [m, m + widths[0] + gap, m + widths[0] + widths[1] + 2 * gap]
            ZStack(alignment: .topLeading) {
                style.color(\.ground)
                ForEach(Lane.allCases, id: \.self) { lane in
                    LaneBox(width: widths[lane.rawValue], height: laneHeight) { content(lane) }
                        .offset(x: CGFloat(lefts[lane.rawValue]), y: CGFloat(laneTop))
                }
                Handle(height: laneHeight, value: $leading, sign: 1)
                    .offset(x: CGFloat(lefts[0] + widths[0]), y: CGFloat(laneTop))
                Handle(height: laneHeight, value: $trailing, sign: -1)
                    .offset(x: CGFloat(lefts[1] + widths[1]), y: CGFloat(laneTop))
                Blob(open: $menu, choose: choose)
                    .offset(x: CGFloat(m), y: CGFloat(top))
            }
            .animation(style.ease(Design.Duration.lane), value: widths)
        }
        .environment(\.style, style)
        .font(style.font())
        .ignoresSafeArea()
        .onAppear { model.start() }
    }

    private func widths(available: Double) -> [Double] {
        let fold = Design.Size.foldedWidth
        if big == .center { return [fold, available - 2 * fold, fold] }
        if big == .trailing { return [fold, fold, available - 2 * fold] }
        func clean(_ v: Double) -> Double { v < Design.Size.foldThreshold ? fold : max(v, Design.Size.laneMinimumLeft) }
        var l = clean(leading), r = clean(trailing)
        let room = available - Design.Size.middleMinimumWidth
        if l + r > room { r = fold; if l > room - r { l = fold } }
        return [l, available - l - r, r]
    }

    private func choose(_ key: String) {
        menu = false
        switch key {
        case "draws.area.sheet": big = big == .center ? nil : .center
        case "draws.area.packs":
            big = nil
            leading = Design.Size.laneRestWidth
        case "draws.area.views", "draws.area.export":
            big = nil
            trailing = Design.Size.laneRestWidth
            model.tab = key == "draws.area.views" ? .view : .export
        case "draws.area.claude":
            if big != .center { big = nil }
            model.assistant = true
        default: break
        }
    }

    private func grow(_ lane: Lane) -> Binding<Bool> {
        Binding(get: { big == lane }, set: { big = $0 ? lane : nil })
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
    @Binding var value: Double
    let sign: Double
    @State private var start: Double?
    @State private var hovering = false

    var body: some View {
        let active = hovering || start != nil
        RoundedRectangle(cornerRadius: CGFloat(Design.Radius.stroke))
            .fill(style.color(active ? \.ink : \.inkTertiary))
            .frame(width: CGFloat(active ? Design.Size.handleThicknessActive : Design.Size.hairline),
                   height: CGFloat(active ? Design.Size.handleLengthActive : Design.Size.handleLength))
            .animation(style.ease(Design.Duration.short), value: active)
            .frame(width: CGFloat(Design.Size.gutter), height: CGFloat(height))
            .overlay(alignment: .top) {
                if start != nil {
                    Text(verbatim: String(format: word("draws.handle.value"), Int(value.rounded())))
                        .font(style.font(Design.TextSize.small))
                        .monospacedDigit()
                        .fixedSize()
                        .padding(.horizontal, CGFloat(Design.Size.menuRowPadding))
                        .frame(height: CGFloat(Design.Size.chipHeight))
                        .foregroundStyle(style.color(\.onInverse))
                        .background(Capsule().fill(style.color(\.inverse)))
                        .padding(.top, CGFloat(Design.Spacing.step12))
                }
            }
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .onHover { hovering = $0 }
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { drag in
                    let s = start ?? value
                    start = s
                    value = max(Design.Size.foldedWidth, s + Double(drag.translation.width) * sign)
                }
                .onEnded { _ in start = nil })
            .onTapGesture(count: 2) { value = Design.Size.laneRestWidth }
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
