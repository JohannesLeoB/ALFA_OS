import ShellCore
import SwiftUI

struct BlobSearch: View {
    let theme: Theme
    @Bindable var model: ShellModel
    @FocusState private var focused: Bool
    @State private var tape = 0.0
    @State private var fade = 0.0

    var body: some View {
        let icon = CGFloat(SheetValues.iconSize)
        HStack(spacing: CGFloat(Design.Size.menuRowGap)) {
            ZStack(alignment: .leading) {
                if model.query.isEmpty {
                    theme.text("menu.search")
                        .opacity(SheetValues.placeholderOpacity)
                        .allowsHitTesting(false)
                }
                TextField("", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onKeyPress(.downArrow) { step(down: true) }
                    .onKeyPress(.upArrow) { step(down: false) }
                    .onKeyPress(.escape) {
                        model.close()
                        return .handled
                    }
                    .onSubmit { model.chooseHot(entries) }
                    .accessibilityLabel(theme.text("menu.search"))
            }
            .font(theme.font())
            .modifier(SearchFade(progress: fade))
            SearchGlyphShape()
                .stroke(style: StrokeStyle(lineWidth: CGFloat(SheetValues.iconStroke * SheetValues.iconSize / SheetValues.iconBox), lineCap: .round))
                .frame(width: icon, height: icon)
                .opacity(SheetValues.iconOpacity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(Design.Size.symbolSize))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.foreground)
                .frame(height: CGFloat(Design.Size.hairline))
                .scaleEffect(x: CGFloat(tape), y: 1, anchor: .trailing)
        }
        .padding(.leading, CGFloat(Design.Spacing.step8))
        .padding(.trailing, CGFloat(Design.Spacing.step16))
        .task {
            if theme.still {
                tape = 1
                fade = 1
            } else {
                withAnimation(theme.ease(Design.Duration.searchUnderline)) { tape = 1 }
                withAnimation(.linear(duration: Design.Duration.searchUnderline)) { fade = 1 }
            }
            try? await Task.sleep(for: .seconds(Design.Duration.menuFocusDelay))
            focused = true
        }
    }

    private var entries: [AppEntry] {
        model.menuLines(title: theme.string).compactMap(\.entry)
    }

    private func step(down: Bool) -> KeyPress.Result {
        let count = entries.count
        guard count > 0 else { return .ignored }
        model.moveHot(down: down, count: count)
        return .handled
    }
}

struct SearchFade: ViewModifier, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let start = SheetValues.tapeFadeAt
        content.opacity(progress < start ? 0 : (progress - start) / (1 - start))
    }
}

struct SearchGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let glyph = SheetValues.searchGlyph
        let scale = rect.width / CGFloat(SheetValues.iconBox)
        func point(_ p: Point) -> CGPoint { CGPoint(x: rect.minX + CGFloat(p.x) * scale, y: rect.minY + CGFloat(p.y) * scale) }
        var path = Path()
        let radius = CGFloat(glyph.radius) * scale
        let center = point(glyph.center)
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        path.move(to: point(glyph.from))
        path.addLine(to: point(glyph.to))
        return path
    }
}

struct BlobMenu: View {
    let theme: Theme
    @Bindable var model: ShellModel
    let host: AppHost?
    let up: Bool
    @State private var reel = false
    @State private var height = CGFloat.zero
    @State private var aim: Task<Void, Never>?

    var body: some View {
        let lines = model.menuLines(title: theme.string)
        let room = CGFloat(model.blob.menuRoom(window: model.window, geometry: theme.geometry))
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                line.padding(.horizontal, CGFloat(Design.Size.menuSeparatorInset)).padding(.bottom, CGFloat(Design.Spacing.step8))
                ForEach(Array(lines.enumerated()), id: \.element.id) { index, item in
                    reeled(index) {
                        switch item {
                        case .separator:
                            line.padding(.horizontal, CGFloat(Design.Size.menuSeparatorInset)).padding(.vertical, CGFloat(Design.Size.menuSeparatorSpace))
                        case .entry(let entry, let hit):
                            row(entry, hit: hit)
                        }
                    }
                }
                if lines.isEmpty {
                    theme.text("menu.empty")
                        .opacity(SheetValues.mutedOpacity)
                        .padding(.horizontal, CGFloat(Design.Size.menuRowPadding))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: CGFloat(Design.Size.menuRowHeight))
                }
            }
            .padding(.horizontal, CGFloat(Design.Size.menuEdge))
            .padding(.bottom, CGFloat(Design.Size.menuEdge))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollIndicators(.never)
        .frame(height: min(height, room))
        .font(theme.font())
        .onHover { inside in if !inside { leave() } }
        .task {
            if theme.still {
                reel = true
                return
            }
            try? await Task.sleep(for: .seconds(Design.Duration.menuReelDelay))
            reel = true
        }
    }

    private var line: some View {
        Rectangle().fill(theme.design(\.inverseLine)).frame(height: CGFloat(Design.Size.hairline))
    }

    private func reeled<Content: View>(_ index: Int, @ViewBuilder _ content: () -> Content) -> some View {
        let delay = Double(min(index, Design.Count.menuStaggerMax)) * Design.Duration.reelStagger
        let shown = reel || theme.still
        return content()
            .modifier(ReelEffect(angle: shown ? 0 : (up ? Design.Motion.menuReelTilt : -Design.Motion.menuReelTilt), bottom: up))
            .animation(theme.ease(Design.Duration.menuReelTransform, delay: delay), value: shown)
            .opacity(shown ? 1 : 0)
            .animation(theme.ease(Design.Duration.rowSequence, delay: delay), value: shown)
    }

    private func row(_ entry: AppEntry, hit: Int) -> some View {
        let current = entry.id == model.currentID
        let count = badge(entry.id)
        return HStack(spacing: CGFloat(Design.Size.menuRowGap)) {
            theme.text(entry.titleKey)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if count > 0 {
                Text(verbatim: String(count))
                    .font(theme.font(Design.TextSize.small))
                    .monospacedDigit()
                    .opacity(SheetValues.mutedOpacity)
            }
        }
        .font(theme.font(weight: current ? Design.Weight.semibold : Design.Weight.regular))
        .padding(.horizontal, CGFloat(Design.Size.menuRowPadding))
        .frame(height: CGFloat(Design.Size.menuRowHeight))
        .background(
            RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
                .fill(model.hot == hit ? theme.design(\.inverseHot) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { inside in if inside { target(hit) } }
        .onTapGesture { model.select(entry.id) }
        .accessibilityAddTraits(.isButton)
    }

    private func badge(_ id: String) -> Int {
        switch id {
        case "mail": host?.unread ?? 0
        case "settings": host?.failedInlets ?? 0
        default: 0
        }
    }

    private func target(_ hit: Int) {
        guard model.hot != hit else { return }
        aim?.cancel()
        aim = Task {
            try? await Task.sleep(for: .seconds(Design.Duration.menuHoverDelay))
            guard !Task.isCancelled else { return }
            model.aim(hit)
        }
    }

    private func leave() {
        aim?.cancel()
        model.clearHot()
    }
}

struct ReelEffect: GeometryEffect {
    var angle: Double
    let bottom: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let pivotX = size.width / 2
        let pivotY = bottom ? size.height : 0
        var form = CATransform3DIdentity
        form.m34 = -1 / CGFloat(Design.Size.menuReelPerspective)
        form = CATransform3DRotate(form, CGFloat(angle * .pi / 180), 1, 0, 0)
        let toPivot = CATransform3DMakeTranslation(-pivotX, -pivotY, 0)
        let back = CATransform3DMakeTranslation(pivotX, pivotY, 0)
        return ProjectionTransform(CATransform3DConcat(CATransform3DConcat(toPivot, form), back))
    }
}

struct BlobAssistant: View {
    let theme: Theme
    let model: ShellModel
    let host: AppHost?

    var body: some View {
        let inset = CGFloat(Design.Size.menuRowPadding)
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step12)) {
            Rectangle().fill(theme.design(\.inverseLine)).frame(height: CGFloat(Design.Size.hairline)).padding(.horizontal, inset)
            if model.face != .orb {
                HStack(spacing: CGFloat(Design.Size.menuRowGap)) {
                    ThinkingOrb(theme: theme, size: Design.Spacing.step20)
                    theme.text("assistant.title").font(theme.font(weight: Design.Weight.medium))
                }
                .padding(.horizontal, inset)
            }
            theme.text(assistantKey)
                .lineSpacing(Typeface.leading(size: Design.TextSize.body, weight: Design.Weight.regular))
                .fixedSize(horizontal: false, vertical: true)
                .opacity(SheetValues.mutedOpacity)
                .padding(.horizontal, inset)
            theme.text("assistant.field")
                .padding(.horizontal, inset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: CGFloat(Design.Size.assistantFieldHeight))
                .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)).fill(theme.design(\.inverseField)))
                .opacity(SheetValues.fieldOpacity)
        }
        .font(theme.font())
        .padding(.horizontal, CGFloat(Design.Size.menuEdge))
        .padding(.bottom, CGFloat(Design.Size.menuEdge))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(theme.text("assistant.title"))
    }

    private var assistantKey: String {
        if host?.assistantFailed == true { return "assistant.failed" }
        return model.currentID == "mail" && host?.stackEmpty != false ? "assistant.noMessage" : "assistant.idle"
    }
}
