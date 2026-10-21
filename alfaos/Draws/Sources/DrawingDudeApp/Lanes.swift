import DrawingKit
import ShellCore
import SwiftUI

struct ProjectLane: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Head {
                HeadTitle(key: "draws.lane.project",
                          detail: [model.project["lastName"], model.project["project"]].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHead(key: "draws.section.project")
                    ForEach(DrawsModel.fields, id: \.self) { key in
                        FieldRow(label: word("draws.field.\(key)"), value: Binding(
                            get: { model.project[key] ?? "" },
                            set: { model.project[key] = $0 }))
                    }
                    SectionHead(key: "draws.section.packs")
                    ListRow(name: word("draws.pack.ci"), symbol: "shippingbox",
                            meta: word(model.ci?.pack.placeholder == true ? "draws.pack.placeholder" : "draws.pack.real"))
                    ListRow(name: word("draws.pack.template"), symbol: "doc",
                            meta: model.template.map { "\($0.pack.format) · \(word($0.pack.placeholder ? "draws.pack.placeholder" : "draws.pack.real"))" } ?? "")
                    defects
                    object
                    if !model.assumptions.isEmpty {
                        SectionHead(key: "draws.section.assumptions")
                        ForEach(Array(model.assumptions.enumerated()), id: \.offset) { Note(text: $0.element, tone: \.inkSecondary) }
                    }
                    if !model.questions.isEmpty {
                        SectionHead(key: "draws.section.questions")
                        ForEach(Array(model.questions.enumerated()), id: \.offset) { Note(text: $0.element, tone: \.signal) }
                    }
                }
                .padding(CGFloat(Design.Spacing.step8))
            }
            .scrollIndicators(.hidden)
            Menu {
                Button(word("draws.object.file")) { model.open() }
                Button(word("draws.object.claude")) { model.assistant = true }
                Divider()
                Button(word("draws.object.clear"), role: .destructive) { model.clear() }
            } label: {
                Compose(key: "draws.object.load", symbol: "plus") {}
                    .allowsHitTesting(false)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
    }

    @ViewBuilder
    private var defects: some View {
        let missing = model.missing, packs = model.defects, misfits = model.misfits
        let count = missing.count + packs.count + misfits.count + (model.overflow ? 1 : 0)
        SectionHead(key: "draws.section.defects", meta: count > 0 ? "\(count)" : "", metaTone: \.signal)
        if count == 0 {
            Note(text: word("draws.defects.none"))
        }
        ForEach(missing, id: \.self) { key in
            ListRow(name: String(format: word("draws.defects.field"), word("draws.field.\(key)")), symbol: "exclamationmark.triangle",
                    meta: word("draws.defects.fill"), symbolTone: \.signal)
        }
        ForEach(misfits) { cell in
            ListRow(name: String(format: word("draws.defects.cell"), model.name(cell)), symbol: "exclamationmark.triangle",
                    meta: word("draws.defects.auto"), symbolTone: \.signal) { model.edit(cell.id) { $0.scale = nil } }
        }
        if model.overflow {
            ListRow(name: word("draws.defects.overflow"), symbol: "exclamationmark.triangle",
                    meta: word("draws.defects.auto"), symbolTone: \.signal) { model.autoScale() }
        }
        ForEach(Array(packs.enumerated()), id: \.offset) { _, d in
            ListRow(name: d, symbol: "exclamationmark.triangle", symbolTone: \.signal)
        }
    }

    @ViewBuilder
    private var object: some View {
        SectionHead(key: "draws.section.object", meta: model.objectName)
        if model.parts.isEmpty {
            Note(text: word("draws.object.empty"))
        }
        ForEach(model.parts, id: \.id) { p in
            let off = model.hidden.contains(p.id), lit = model.accent == p.id
            ListRow(name: p.name, symbol: "cube", meta: "\(Int(p.w)) × \(Int(p.d)) × \(Int(p.h))",
                    bold: lit, dim: off, symbolTone: lit ? \.signal : \.inkTertiary,
                    end: (off ? "eye.slash" : "eye", word(off ? "draws.object.show" : "draws.object.hide"), {
                        if off { model.hidden.remove(p.id) } else { model.hidden.insert(p.id) }
                    })) {
                model.accent = lit ? nil : p.id
            }
            .help(word(lit ? "draws.object.unaccent" : "draws.object.accent"))
        }
    }
}

struct SheetLane: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel
    @Binding var maximized: Bool
    @State private var zoom = 1.0
    @State private var settled = 1.0
    @State private var pan = CGSize.zero
    @State private var panned = CGSize.zero

    var body: some View {
        VStack(spacing: 0) {
            Head {
                HeadTitle(key: "draws.lane.sheet", detail: model.template?.pack.format)
                Choice(value: word("draws.product.\(model.layout.rawValue)")) {
                    ForEach(Kind.allCases, id: \.self) { kind in
                        Toggle(word("draws.product.\(kind.rawValue)"), isOn: Binding(
                            get: { model.layout == kind }, set: { if $0 { model.layout = kind } }))
                    }
                }
                Divide()
                SymbolButton(symbol: "minus.magnifyingglass", tip: word("draws.zoom.out"), enabled: zoom > Proto.zoomMin) {
                    set(zoom / Proto.zoomStep)
                }
                Text(verbatim: String(format: word("draws.zoom.value"), Int((zoom * 100).rounded())))
                    .font(style.font(Design.TextSize.small))
                    .monospacedDigit()
                    .foregroundStyle(style.color(\.inkSecondary))
                    .padding(.horizontal, CGFloat(Design.Spacing.step8))
                    .frame(height: CGFloat(Design.Spacing.step28))
                    .contentShape(Capsule())
                    .onTapGesture { reset() }
                    .help(word("draws.zoom.fit"))
                SymbolButton(symbol: "plus.magnifyingglass", tip: word("draws.zoom.in"), enabled: zoom < Proto.zoomMax) {
                    set(zoom * Proto.zoomStep)
                }
                Divide()
                SymbolButton(symbol: "grid", tip: word("draws.raster"), on: model.raster) { model.raster.toggle() }
                SymbolButton(symbol: maximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                             tip: word(maximized ? "draws.sheet.back" : "draws.sheet.max")) { maximized.toggle() }
            }
            GeometryReader { proxy in
                ZStack {
                    ZStack {
                        style.color(\.well)
                        if let sheet = model.sheet {
                            canvas(sheet, room: proxy.size)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(MagnifyGesture()
                        .onChanged { zoom = min(Proto.zoomMax, max(Proto.zoomMin, settled * Double($0.magnification))) }
                        .onEnded { _ in settled = zoom })
                    .simultaneousGesture(DragGesture()
                        .onChanged {
                            guard model.grip == nil else { return }
                            pan = CGSize(width: panned.width + $0.translation.width, height: panned.height + $0.translation.height)
                        }
                        .onEnded { _ in if model.grip == nil { panned = pan } })
                    .onTapGesture(count: 2) { reset() }
                    .onTapGesture { model.selected = nil }
                    if model.parts.isEmpty && !model.assistant {
                        EmptyCard(model: model)
                    }
                    if model.assistant {
                        VStack { ClaudePanel(model: model); Spacer(minLength: 0) }
                            .padding(.top, CGFloat(Design.Spacing.step16))
                    }
                    VStack {
                        Spacer(minLength: 0)
                        HStack(spacing: CGFloat(Design.Spacing.step8)) {
                            status
                            Spacer(minLength: 0)
                            if model.pages.count > 1 { pager }
                        }
                    }
                    .padding(CGFloat(Design.Spacing.step12))
                }
                .clipped()
            }
        }
    }

    private func set(_ z: Double) {
        zoom = min(Proto.zoomMax, max(Proto.zoomMin, z))
        settled = zoom
    }

    private func reset() {
        zoom = 1; settled = 1; pan = .zero; panned = .zero
    }

    private var status: some View {
        let format = model.template?.pack.format ?? ""
        let count = model.pages.count
        let text: String
        var tone: KeyPath<DesignColors, RGB> = \.inkSecondary
        if let grip = model.grip, grip.moved, let cell = model.cell(grip.id) {
            let f = cell.frame
            text = String(format: word("draws.status.drag"), model.name(cell), Int(f.minX.rounded()), Int(f.minY.rounded()),
                          Int(f.width.rounded()), Int(f.height.rounded()))
        } else if model.overflow {
            text = String(format: word("draws.status.overflow"), format); tone = \.signal
        } else if let failure = model.failure {
            text = failure; tone = \.signal
        } else if model.shown.isEmpty {
            text = String(format: word("draws.status.empty"), format)
        } else if !model.misfits.isEmpty {
            text = String(format: word("draws.status.nofit"),
                          model.misfits.map(model.name).formatted(.list(type: .and).locale(Locale(identifier: "de"))))
            tone = \.signal
        } else {
            text = String(format: word("draws.status.normal"), format,
                          count == 1 ? word("draws.pages.one") : String(format: word("draws.pages.many"), count))
                + (model.raster ? String(format: word("draws.status.raster"), Int(Proto.grid)) : "")
        }
        return Text(verbatim: text)
            .font(style.font(Design.TextSize.small))
            .monospacedDigit()
            .foregroundStyle(style.color(tone))
            .lineLimit(1)
            .padding(.horizontal, CGFloat(Design.Spacing.step12))
            .frame(height: CGFloat(Design.Spacing.step24))
            .background(Capsule().fill(style.color(\.lane)))
            .shadowed(style, style.shadow(\.lane), Capsule())
    }

    private var pager: some View {
        HStack(spacing: CGFloat(Design.Spacing.step4)) {
            SymbolButton(symbol: "chevron.left", tip: word("draws.page.back"), enabled: model.page > 0) { model.turn(-1) }
            Text(verbatim: "\(model.page + 1)/\(model.pages.count)")
                .font(style.font(Design.TextSize.small))
                .monospacedDigit()
                .foregroundStyle(style.color(\.inkSecondary))
            SymbolButton(symbol: "chevron.right", tip: word("draws.page.next"), enabled: model.page < model.pages.count - 1) { model.turn(1) }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step4))
        .background(Capsule().fill(style.color(\.lane)))
        .shadowed(style, style.shadow(\.lane), Capsule())
    }

    private func canvas(_ sheet: Sheet, room: CGSize) -> some View {
        let pad = Proto.deskPadding
        let fit = max(0.01, min((Double(room.width) - 2 * pad) / sheet.width, (Double(room.height) - 2 * pad) / sheet.height))
        let k = fit * zoom
        let field = model.field
        return Canvas { context, _ in
            context.withCGContext { cg in
                cg.scaleBy(x: k, y: k)
                SheetExporter.draw(sheet, in: cg)
            }
            guard model.raster || model.grip?.moved == true, let field else { return }
            var minor = Path(), major = Path()
            var x = field.minX
            while x <= field.maxX + 0.01 {
                let step = Int(((x - field.minX) / Proto.grid).rounded())
                let line = Path { p in p.move(to: CGPoint(x: x * k, y: field.minY * k)); p.addLine(to: CGPoint(x: x * k, y: field.maxY * k)) }
                if step % Int(Proto.gridMajor / Proto.grid) == 0 { major.addPath(line) } else { minor.addPath(line) }
                x += Proto.grid
            }
            var y = field.minY
            while y <= field.maxY + 0.01 {
                let step = Int(((y - field.minY) / Proto.grid).rounded())
                let line = Path { p in p.move(to: CGPoint(x: field.minX * k, y: y * k)); p.addLine(to: CGPoint(x: field.maxX * k, y: y * k)) }
                if step % Int(Proto.gridMajor / Proto.grid) == 0 { major.addPath(line) } else { minor.addPath(line) }
                y += Proto.grid
            }
            let c = DesignColors.light
            context.stroke(minor, with: .color(style.layerColor(c.sheetLine)), lineWidth: CGFloat(Design.Size.hairline))
            context.stroke(major, with: .color(style.layerColor(c.sheetLineStrong)), lineWidth: CGFloat(Design.Size.hairline))
        }
        .frame(width: CGFloat(sheet.width * k), height: CGFloat(sheet.height * k))
        .overlay(alignment: .topLeading) {
            if model.layout != .presentation, let field {
                BoardOverlay(model: model, sheet: sheet, k: k, field: field)
            }
        }
        .background(style.color(\.sheet))
        .shadowed(style, style.shadow(\.floating), Rectangle())
        .offset(pan)
    }
}

struct BoardOverlay: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel
    let sheet: Sheet
    let k: Double
    let field: CGRect
    @State private var start: CGRect?
    @State private var guides: [Guide] = []

    var body: some View {
        let dash = CGFloat(Design.Spacing.step4)
        ZStack(alignment: .topLeading) {
            ForEach(model.cells) { cell in
                let frame = scaled(cell.frame)
                Color.clear
                    .overlay(outline(cell, dash: dash))
                    .frame(width: frame.width, height: frame.height)
                    .contentShape(Rectangle())
                    .offset(x: frame.minX, y: frame.minY)
                    .gesture(move(cell))
            }
            Path { path in
                for guide in guides {
                    if guide.vertical {
                        path.move(to: CGPoint(x: guide.at * k, y: 0))
                        path.addLine(to: CGPoint(x: guide.at * k, y: sheet.height * k))
                    } else {
                        path.move(to: CGPoint(x: 0, y: guide.at * k))
                        path.addLine(to: CGPoint(x: sheet.width * k, y: guide.at * k))
                    }
                }
            }
            .stroke(style.color(\.sheetInkTertiary), style: StrokeStyle(lineWidth: CGFloat(Design.Size.hairline), dash: [dash, dash]))
            .allowsHitTesting(false)
            if let cell = model.cell(model.selected) {
                ForEach(Corner.allCases, id: \.self) { handle($0, cell) }
            }
        }
        .frame(width: CGFloat(sheet.width * k), height: CGFloat(sheet.height * k), alignment: .topLeading)
    }

    private func scaled(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX * k, y: r.minY * k, width: r.width * k, height: r.height * k)
    }

    private func outline(_ cell: Cell, dash: CGFloat) -> some View {
        let fits = model.placed(cell.id)?.fits ?? true
        return ZStack {
            if cell.id == model.selected {
                Rectangle().strokeBorder(style.color(\.sheetInk), lineWidth: CGFloat(Design.Size.hairline))
            }
            if !fits {
                Rectangle().strokeBorder(style.color(\.signal), style: StrokeStyle(lineWidth: CGFloat(Design.Size.hairline), dash: [dash, dash]))
            }
        }
        .allowsHitTesting(false)
    }

    private func handle(_ corner: Corner, _ cell: Cell) -> some View {
        let dot = CGFloat(Design.Spacing.statusDot)
        let frame = scaled(cell.frame)
        let x = corner.right ? frame.maxX : frame.minX, y = corner.bottom ? frame.maxY : frame.minY
        return Rectangle()
            .fill(style.color(\.sheet))
            .overlay(Rectangle().strokeBorder(style.color(\.sheetInk), lineWidth: CGFloat(Design.Size.hairline)))
            .frame(width: dot, height: dot)
            .padding(dot / 2)
            .contentShape(Rectangle())
            .offset(x: x - dot, y: y - dot)
            .gesture(resize(corner, cell))
    }

    private func reach(_ drag: DragGesture.Value) -> Bool {
        model.grip?.moved == true || hypot(drag.translation.width, drag.translation.height) >= Proto.snap
    }

    private func millimeters(_ drag: DragGesture.Value) -> CGSize {
        CGSize(width: drag.translation.width / k, height: drag.translation.height / k)
    }

    private func grab(_ cell: Cell) {
        guard model.grip?.id != cell.id else { return }
        model.grip = Grip(id: cell.id)
        start = cell.frame
    }

    private func release() {
        model.grip = nil
        start = nil
        guides = []
    }

    private func move(_ cell: Cell) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { drag in
                grab(cell)
                model.selected = cell.id
                guard let start, reach(drag) else { return }
                if model.grip?.moved != true { model.grip?.moved = true }
                let result = Snap.move(start, by: millimeters(drag), others: model.cells.filter { $0.id != cell.id }.map(\.frame),
                                       field: field, sheet: CGSize(width: sheet.width, height: sheet.height), reach: Proto.snap / k)
                guides = result.guides
                model.edit(cell.id) { $0.frame = result.frame }
            }
            .onEnded { _ in release() }
    }

    private func resize(_ corner: Corner, _ cell: Cell) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { drag in
                grab(cell)
                guard let start, reach(drag) else { return }
                if model.grip?.moved != true { model.grip?.moved = true }
                let frame = Snap.resize(start, corner: corner, by: millimeters(drag), field: field,
                                        sheet: CGSize(width: sheet.width, height: sheet.height))
                model.edit(cell.id) { $0.frame = frame }
            }
            .onEnded { _ in release() }
    }
}

struct Divide: View {
    @Environment(\.style) private var style

    var body: some View {
        Rectangle().fill(style.color(\.line))
            .frame(width: CGFloat(Design.Size.hairline), height: CGFloat(Design.Spacing.step20))
            .padding(.horizontal, CGFloat(Design.Spacing.step4))
    }
}

struct EmptyCard: View {
    @Environment(\.style) private var style
    let model: DrawsModel

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.contextMenu))
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step8)) {
            say("draws.empty.title").font(style.font(Design.TextSize.body, weight: Design.Weight.medium)).foregroundStyle(style.color(\.ink))
            say("draws.empty.text").font(style.font(Design.TextSize.small)).foregroundStyle(style.color(\.inkTertiary))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Pill(key: "draws.object.load", accent: true) { model.open() }
                Pill(key: "draws.claude.title") { model.assistant = true }
            }
            .padding(.top, CGFloat(Design.Spacing.step4))
        }
        .padding(CGFloat(Design.Spacing.step16))
        .frame(width: CGFloat(Proto.emptyWidth), alignment: .leading)
        .background(shape.fill(style.color(\.menu)))
        .shadowed(style, style.shadow(\.floating), shape)
    }
}

struct InspectorLane: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel
    @Binding var maximized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Head(stack: true) {
                Segments(options: Tab.allCases.map { ($0, "draws.tab.\($0.rawValue)") }, selection: $model.tab, fill: true)
                SymbolButton(symbol: maximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                             tip: word(maximized ? "draws.sheet.back" : "draws.inspector.max")) { maximized.toggle() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch model.tab {
                    case .view: ViewTab(model: model)
                    case .style: StyleTab(model: model)
                    case .export: ExportTab(model: model)
                    }
                }
                .padding(CGFloat(Design.Spacing.step8))
            }
            .scrollIndicators(.hidden)
            if model.tab == .export {
                let n = model.missing.count + model.defects.count
                Compose(key: model.pdf ? "draws.export.savePDF" : "draws.export.saveSVG", symbol: "square.and.arrow.down",
                        extra: n > 0 && !model.stuck ? String(format: word("draws.export.despite"), n) : "") {
                    model.export()
                }
                .opacity(model.sheet == nil ? Proto.disabled : 1)
                .allowsHitTesting(model.sheet != nil)
            }
        }
    }
}

struct ViewTab: View {
    @Bindable var model: DrawsModel

    var body: some View {
        if model.layout == .presentation {
            SectionHead(key: "draws.section.pages", meta: "\(model.pages.count)")
            ForEach(Array(model.pages.enumerated()), id: \.offset) { index, sheet in
                ListRow(name: model.pages.count > 1 ? String(format: word("draws.page.step"), index + 1) : word("draws.product.presentation"),
                        symbol: "cube", meta: sheet.scale > 0 ? "1:\(Int(sheet.scale))" : "", selected: index == model.page) {
                    model.page = index
                }
            }
        } else {
            SectionHead(key: "draws.section.pages", meta: "\(model.cells.count)")
            ForEach(model.cells) { cell in
                let fits = model.placed(cell.id)?.fits ?? true
                ListRow(name: model.name(cell), symbol: symbol(cell),
                        meta: model.placed(cell.id).map { "1:\(Int($0.scale))" } ?? "",
                        selected: cell.id == model.selected, tone: fits ? \.ink : \.signal, metaTone: fits ? \.inkTertiary : \.signal) {
                    model.selected = cell.id == model.selected ? nil : cell.id
                }
            }
        }
        if model.sheet == nil { Note(text: word("draws.view.none")) }
        if model.layout != .presentation, let cell = model.cell(model.selected) { selection(cell) }
        SectionHead(key: "draws.section.sheet", meta: model.template?.pack.format ?? "")
        if model.layout == .presentation {
            Labeled(key: "draws.views.dimensions") { Switch(on: $model.dimensions) }
        }
        Labeled(key: "draws.view.fill") {
            Segments(options: [(Fill.tone, "draws.fill.tone"), (Fill.material, "draws.fill.material")], selection: $model.fill)
        }
        Labeled(key: "draws.views.method") {
            Text(verbatim: word(model.template?.pack.method == .third ? "draws.method.third" : "draws.method.first"))
        }
    }

    @ViewBuilder
    private func selection(_ cell: Cell) -> some View {
        let id = cell.id, ortho = cell.form == .ortho
        let placed = model.placed(id)
        let scales = model.scales(for: cell)
        SectionHead(key: "draws.section.view", meta: model.name(cell), metaTone: placed?.fits == false ? \.signal : \.inkTertiary)
        Labeled(key: "draws.cell.type") {
            Segments(options: [(CellForm.ortho, "draws.type.ortho"), (CellForm.iso, "draws.type.iso"),
                               (CellForm.perspective, "draws.type.perspective")],
                     selection: Binding(get: { model.cell(id)?.form ?? .ortho },
                                        set: { next in model.edit(id) { $0.become(next) } }))
        }
        Labeled(key: "draws.cell.dir", enabled: ortho) {
            Segments(options: [(ViewKind.front, "draws.dir.front"), (ViewKind.right, "draws.dir.right"),
                               (ViewKind.top, "draws.dir.top"), (ViewKind.back, "draws.dir.back")],
                     selection: Binding(get: { model.cell(id)?.view ?? .front },
                                        set: { next in model.edit(id) { $0.view = next } }))
        }
        Labeled(key: "draws.view.focus") {
            Choice(value: cell.focus.flatMap { focus in model.parts.first { $0.id == focus }?.name } ?? word("draws.view.whole")) {
                Button(word("draws.view.whole")) { model.edit(id) { $0.focus = nil } }
                Divider()
                ForEach(model.parts, id: \.id) { p in Button(p.name) { model.edit(id) { $0.focus = p.id } } }
            }
        }
        Labeled(key: "draws.cell.steps", enabled: !ortho) {
            Segments(options: stepOptions(placed?.steps ?? 0),
                     selection: Binding(get: { model.cell(id)?.step ?? 0 }, set: { next in model.edit(id) { $0.step = next } }),
                     literal: true)
        }
        Labeled(key: "draws.view.scale") {
            Segments(options: [(false, "draws.scale.auto"), (true, "draws.scale.fixed")], selection: Binding(
                get: { model.cell(id)?.scale != nil },
                set: { fixed in model.edit(id) { $0.scale = fixed ? (placed?.scale ?? scales.first) : nil } }))
        }
        Labeled(key: "draws.view.fixed", enabled: cell.scale != nil) {
            Choice(value: "1:\(Int(cell.scale ?? placed?.scale ?? 0))") {
                ForEach(scales, id: \.self) { n in Button("1:\(Int(n))") { model.edit(id) { $0.scale = n } } }
            }
        }
        Labeled(key: "draws.views.dimensions", enabled: ortho) {
            Switch(on: Binding(get: { ortho && (model.cell(id)?.dims ?? false) }, set: { on in model.edit(id) { $0.dims = on } }))
        }
    }

    private func stepOptions(_ count: Int) -> [(id: Int, key: String)] {
        [(id: 0, key: word("draws.cell.stepsOff"))] + (0..<count).map { (id: $0 + 1, key: "\($0 + 1)") }
    }

    private func symbol(_ cell: Cell) -> String {
        switch cell.form {
        case .ortho: return "rectangle.split.2x1"
        case .perspective: return "trapezoid.and.line.vertical"
        case .iso: return cell.step > 0 ? "stairs" : "cube"
        }
    }
}

struct StyleTab: View {
    @Bindable var model: DrawsModel

    var body: some View {
        SectionHead(key: "draws.style.look", meta: word("draws.style.lookMeta"))
        SliderRow(key: "draws.style.azimuth", dial: Proto.azimuth, value: $model.azimuth,
                  text: String(format: word("draws.unit.degree"), Int(model.azimuth.rounded())))
        SliderRow(key: "draws.style.elevation", dial: Proto.elevation, value: $model.elevation,
                  text: String(format: word("draws.unit.degree"), Int(model.elevation.rounded())))
        SectionHead(key: "draws.style.faces")
        ForEach(0..<3, id: \.self) { i in
            Swatches(key: ["draws.face.top", "draws.face.side", "draws.face.front"][i], colors: Tone.ladder, selected: model.faces[i]) {
                model.faces[i] = $0
                model.fill = .tone
            }
        }
        SectionHead(key: "draws.style.edges")
        SliderRow(key: "draws.edge.inner", dial: Proto.edge, value: $model.edge, text: mm(model.edge))
        SliderRow(key: "draws.edge.outline", dial: Proto.outline, value: $model.outline, text: mm(model.outline))
        SectionHead(key: "draws.style.shadowHead")
        Labeled(key: "draws.style.shadow") { Switch(on: $model.shadowOn) }
        SliderRow(key: "draws.style.strength", dial: Proto.shadow, value: $model.shadow,
                  text: String(format: word("draws.unit.percent"), Int(model.shadow.rounded())), enabled: model.shadowOn)
        SectionHead(key: "draws.style.accentHead")
        Labeled(key: "draws.style.accent") {
            Choice(value: model.accent.flatMap { id in model.parts.first { $0.id == id }?.name } ?? word("draws.style.none")) {
                Button(word("draws.style.none")) { model.accent = nil }
                Divider()
                ForEach(model.parts, id: \.id) { p in Button(p.name) { model.accent = p.id } }
            }
        }
        Swatches(key: "draws.style.color", colors: Tone.accents, selected: model.accentColor) { model.accentColor = $0 }
    }

    private func mm(_ v: Double) -> String {
        String(format: word("draws.unit.mm"), String(format: "%.2f", v).replacingOccurrences(of: ".", with: ","))
    }
}

struct ExportTab: View {
    @Bindable var model: DrawsModel

    var body: some View {
        let n = model.missing.count + model.defects.count
        let pages = model.pdf && model.allPages ? model.pages.count : 1
        SectionHead(key: "draws.export.file")
        Labeled(key: "draws.export.format") {
            Segments(options: [(true, "draws.export.pdf"), (false, "draws.export.svg")], selection: $model.pdf)
        }
        Labeled(key: "draws.export.pages", enabled: model.pdf) {
            Segments(options: [(false, "draws.export.one"), (true, "draws.export.all")], selection: $model.allPages)
        }
        Note(text: String(format: word(model.pdf ? "draws.export.notePDF" : "draws.export.noteSVG"), model.template?.pack.format ?? "",
                          pages == 1 ? word("draws.pages.one") : String(format: word("draws.pages.many"), pages)))
        SectionHead(key: "draws.export.check", meta: n == 0 ? "" : (n == 1 ? word("draws.export.oneDefect") : String(format: word("draws.export.defects"), n)),
                    metaTone: \.signal)
        if model.stuck {
            Note(text: word("draws.export.overflow"), tone: \.signal)
        } else {
            Note(text: word(n == 0 ? "draws.export.clean" : "draws.export.goes"))
        }
        if let failure = model.failure {
            SectionHead(key: "draws.export.error", metaTone: \.signal)
            Note(text: failure, tone: \.signal)
        }
    }
}
