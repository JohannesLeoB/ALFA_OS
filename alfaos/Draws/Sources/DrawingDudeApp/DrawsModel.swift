import AppKit
import CoreGraphics
import DrawingKit
import DrawsAI
import DrawsDock
import DrawsFonts
import Foundation
import Observation
import ShellCore
import UniformTypeIdentifiers

enum Kind: String, CaseIterable {
    case plan, iso, steps, perspective, customer, presentation, cover
}

enum Tab: String, CaseIterable { case view, style, export }

enum Fill: String, CaseIterable { case tone, material }

enum Source: String, CaseIterable { case photo, pdf, text }

enum Tone {
    static func hex(_ v: RGB) -> String {
        func byte(_ c: Double) -> Int { Int((min(1, max(0, c)) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", byte(v.red), byte(v.green), byte(v.blue))
    }

    static var ladder: [String] {
        let c = DesignColors.light
        return [c.sheet, c.sheetWell, c.sheetLine, c.sheetLineStrong, c.handle].map(hex)
    }

    static var faces: [String] {
        let c = DesignColors.light
        return [c.sheetWell, c.sheetLineStrong, c.sheetLine].map(hex)
    }

    static var accents: [String] {
        let c = DesignColors.light, m = DesignMoods.light
        return [c.signal, m.apricot, m.coral, c.sheetInk].map(hex)
    }
}

@MainActor
@Observable
final class DrawsModel {
    static let fields = ["lastName", "project", "street", "city", "customer", "date"]

    var objectName = ""
    var parts: [Part] = []
    var project: [String: String] = [:] { didSet { render() } }
    var number = ""
    var trade = ""
    var checks: [Check] = []
    var fonts = DrawsFonts.fallback
    let dock: Dock
    var ci: Loaded<CIPack>?
    var template: Loaded<TemplatePack>?
    var material: Loaded<MaterialPack>?
    var layout = Kind.plan {
        didSet {
            let was = ready
            ready = false
            fill = layout == .customer || layout == .presentation ? .material : .tone
            page = 0
            selected = nil
            cells = preset()
            ready = was
            render()
        }
    }
    var dimensions = true { didSet { render() } }
    var fill = Fill.tone { didSet { render() } }
    var faces = Tone.faces { didSet { render() } }
    var azimuth = ViewSpec(kind: .iso).azimuth { didSet { render() } }
    var elevation = ViewSpec.isoElevation { didSet { render() } }
    var edge = 0.0 { didSet { render() } }
    var outline = 0.0 { didSet { render() } }
    var shadowOn = true { didSet { render() } }
    var shadow = 0.0 { didSet { render() } }
    var accent: String? { didSet { render() } }
    var accentColor: String? { didSet { render() } }
    var cells: [Cell] = [] { didSet { render() } }
    var selected: String?
    var grip: Grip?
    var hidden: Set<String> = [] {
        didSet {
            if cells.contains(where: { $0.focus.map(hidden.contains) ?? false }) {
                cells = cells.map { cell in
                    var next = cell
                    if let id = cell.focus, hidden.contains(id) { next.focus = nil }
                    return next
                }
            }
            render()
        }
    }
    var raster = false
    var tab = Tab.view
    var pdf = true
    var allPages = true
    var assistant = false
    var source = Source.text
    var pages: [Sheet] = []
    var page = 0
    var failure: String?
    var overflow = false
    var brief = ""
    var attachments: [Attachment] = []
    var designing = false
    var assumptions: [String] = []
    var questions: [String] = []
    var variants: [Variant] = []
    var blocks: [Panel] = []
    var choice = ""
    var presets: [PromptPreset] = []
    var extra: [Material] = []
    var underlayShow = false
    var underlayExport = false
    private(set) var underlayData: Data?
    var underlay: String? {
        didSet {
            underlayData = underlay.flatMap { name in choices.first { $0.name == name } }
                .flatMap { Prepare.underlay($0, side: Proto.underlaySide) }
        }
    }
    private var ready = false
    private let designer: Designer

    init() {
        let places = LocalPlaces(root: LocalPlaces.support)
        places.prepare()
        dock = Dock.local(packs: Self.root.appendingPathComponent("Packs"), places: places)
        designer = ClaudeDesigner(credentials: dock.claude.credentials)
    }

    var sheet: Sheet? { pages.indices.contains(page) ? pages[page] : nil }

    var templates: [PackRef] { dock.templates.packs(.template) }

    var kinds: [Kind] {
        let deck = template?.pack.deck != nil
        return Kind.allCases.filter { deck ? [.presentation, .iso, .perspective, .cover].contains($0) : $0 != .cover }
    }

    static let sheets: [String: Attachment.Role] = ["dxf": .drawing, "idml": .template]

    var choices: [Attachment] {
        attachments.filter { [.sketch, .drawing, .template].contains($0.role) && $0.mediaType != Attachment.text }
    }

    var shown: [Part] {
        parts.filter { !hidden.contains($0.id) }
    }

    var field: CGRect? {
        guard let t = template?.pack else { return nil }
        return CGRect(x: t.frame.left, y: t.frame.top,
                      width: t.width - t.frame.left - t.frame.right, height: t.height - t.frame.top - t.frame.bottom)
    }

    var misfits: [Cell] {
        guard let sheet else { return [] }
        return cells.filter { cell in sheet.cells.first { $0.id == cell.id }.map { !$0.fits } ?? false }
    }

    var stuck: Bool { overflow || !misfits.isEmpty }

    var missing: [String] {
        Self.fields.filter { (project[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var defects: [String] {
        (ci?.defects ?? []) + (template?.defects ?? []) + (material?.defects ?? [])
            + (sheet?.defects ?? []).filter { !$0.hasPrefix("board.") }
    }

    func cell(_ id: String?) -> Cell? {
        id.flatMap { id in cells.first { $0.id == id } }
    }

    func placed(_ id: String) -> Placed? {
        sheet?.cells.first { $0.id == id }
    }

    func scales(for cell: Cell) -> [Double] {
        guard let t = template?.pack else { return [] }
        return (cell.form == .ortho ? t.scales : t.isoScales).sorted()
    }

    func edit(_ id: String, _ change: (inout Cell) -> Void) {
        guard let index = cells.firstIndex(where: { $0.id == id }) else { return }
        var next = cells[index]
        change(&next)
        if next != cells[index] { cells[index] = next }
    }

    func autoScale() {
        cells = cells.map { cell in
            var next = cell
            next.scale = nil
            return next
        }
    }

    func name(_ cell: Cell) -> String {
        let base: String
        switch cell.view {
        case .iso: base = cell.step > 0 ? String(format: word("draws.page.step"), cell.step) : word("draws.product.iso")
        case .perspective: base = word("draws.product.perspective")
        case .front: base = word("draws.cell.front")
        case .back: base = word("draws.cell.back")
        case .top: base = word("draws.cell.top")
        case .left, .right: base = word("draws.cell.side")
        }
        guard let id = cell.focus, let part = parts.first(where: { $0.id == id }) else { return base }
        return String(format: word("draws.cell.focus"), base, part.name)
    }

    func preset() -> [Cell] {
        guard let t = template?.pack, var room = field else { return [] }
        if let deck = t.deck { room.size.height -= deck.captionGap + 2 * deck.captionLeading }
        return Presets.cells(layout, field: room, gap: t.gap, steps: Set(shown.map(\.z)).count)
    }

    func rebuild() {
        selected = nil
        cells = preset()
    }

    func turn(_ step: Int) {
        page = min(max(0, page + step), max(0, pages.count - 1))
    }

    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func start() {
        do {
            ci = try dock.loadCI()
            template = try dock.loadTemplate()
            choice = templates.first?.name ?? ""
            material = try dock.loadMaterial()
            fonts = DrawsFonts.resolve(upload: dock.templates.fonts())
            guard ci != nil, template != nil else {
                failure = word("dock.reason.packs")
                return
            }
            presets = PromptPresets.load(Self.root.appendingPathComponent("Packs/presets/default.json"))
            resetStyle()
            cells = preset()
            ready = true
            load(Self.root.appendingPathComponent("Examples/kueche.json"))
        } catch {
            failure = "\(error)"
        }
    }

    func choose(_ ref: PackRef) {
        do {
            let next = try dock.loadTemplate(ref)
            if let paired = try dock.loadCI(named: next.pack.ciName) {
                ci = paired
            } else if let first = try dock.loadCI() {
                ci = first
            }
            for item in extra { ci?.pack.tints[item.code] = item.tone }
            template = next
            choice = ref.name
            resetStyle()
            layout = kinds.contains(layout) ? layout : (kinds.first ?? .plan)
        } catch {
            failure = "\(error)"
        }
    }

    func resetStyle() {
        let iso = ci?.pack.iso
        let was = ready
        ready = false
        edge = iso?.edge ?? 0
        outline = iso?.outline ?? 0
        shadow = (iso?.shadow ?? 0) * 100
        shadowOn = (iso?.shadow ?? 0) > 0
        faces = Tone.faces
        azimuth = ViewSpec(kind: .iso).azimuth
        elevation = ViewSpec.isoElevation
        accent = nil
        accentColor = nil
        ready = was
        render()
    }

    func load(_ url: URL) {
        do {
            let object = try DrawingObject.load(url)
            try Validate.parts(object.parts)
            ready = false
            parts = object.parts
            project = object.project ?? [:]
            adopt()
            variants = object.variants ?? []
            blocks = object.blocks ?? []
            hidden = []
            accent = nil
            rebuild()
            objectName = url.deletingPathExtension().lastPathComponent
            ready = true
            render()
        } catch {
            failure = "\(error)"
        }
    }

    func adopt() {
        guard let ref = dock.project.current() else { return }
        project.merge(ref.fields) { _, new in new }
        number = ref.projectNumber
    }

    func checkDock() {
        checks = dock.check()
    }

    func clear() {
        ready = false
        parts = []
        blocks = []
        hidden = []
        accent = nil
        rebuild()
        objectName = ""
        ready = true
        render()
    }

    func style() -> IsoStyle? {
        guard var s = ci?.pack.iso else { return nil }
        s.edge = edge
        s.outline = outline
        s.shadow = shadowOn ? shadow / 100 : 0
        s.accent = accent
        s.accentColor = accentColor
        s.faces = fill == .tone ? faces : nil
        return s
    }

    func product() -> Product {
        if layout == .presentation { return .presentation }
        if layout == .cover { return .cover }
        let size = shown.reduce(0.0) { max($0, $1.w, $1.d, $1.h) }
        return .board(cells, ViewSpec(kind: .iso, azimuth: azimuth, elevation: elevation,
                                      distance: Proto.perspectiveDistance * size))
    }

    func render() {
        guard ready, let ci, let template else { return }
        overflow = false
        guard !shown.isEmpty else {
            pages = []
            failure = nil
            return
        }
        do {
            pages = try DrawingEngine.render(Job(parts: shown, ci: ci.pack, template: template.pack, project: project,
                                                 products: [product()], style: style(), dimensions: dimensions,
                                                 material: material?.pack, variants: variants, dims: dimensions ? .given : .none,
                                                 fonts: fonts, blocks: blocks))
            page = min(page, max(0, pages.count - 1))
            failure = nil
        } catch DrawingError.overflow {
            pages = []
            overflow = true
            failure = nil
        } catch {
            pages = []
            failure = "\(error)"
        }
    }

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    var place: Place {
        Stage(status: project["status"]) == .preprint && !trade.isEmpty ? .trade : .presentation
    }

    func fileName(_ ext: String) -> String {
        if let name = ExportName.make(project: project, number: number, trade: trade, variants: variants.map(\.name),
                                      now: Date(), ext: ext) {
            return name
        }
        let base = objectName.components(separatedBy: CharacterSet(charactersIn: "/:")).joined()
        return (base.isEmpty ? "" : "\(base)-") + "\(layout.rawValue).\(ext)"
    }

    func export() {
        guard let sheet else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [pdf ? .pdf : .svg]
        panel.nameFieldStringValue = fileName(pdf ? "pdf" : "svg")
        panel.directoryURL = dock.destination(place, project: number)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let type = pdf ? UTType.pdf : UTType.svg
        let data = pdf ? SheetExporter.pdf(allPages ? pages.map(exported) : [exported(sheet)]) : SheetExporter.svg(exported(sheet))
        send(Deliverable(name: url.lastPathComponent, mimeType: type.preferredMIMEType ?? "", data: data,
                         folder: url.deletingLastPathComponent()), .save)
    }

    func hand(_ handoff: Handoff) {
        guard let sheet else { return }
        let data = SheetExporter.pdf(allPages ? pages.map(exported) : [exported(sheet)])
        send(Deliverable(name: fileName("pdf"), mimeType: UTType.pdf.preferredMIMEType ?? "", data: data), handoff)
    }

    private func send(_ file: Deliverable, _ handoff: Handoff) {
        Task {
            switch await dock.delivery.deliver(file, via: handoff) {
            case .done: break
            case .failed(let reason): failure = reason.hasPrefix("dock.") ? word(reason) : reason
            case .notConnected: failure = word("dock.reason.hub")
            }
        }
    }

    func backed(_ sheet: Sheet) -> Sheet {
        guard let data = underlayData, let field else { return sheet }
        return sheet.underlaid(data, in: field, opacity: Proto.underlay)
    }

    func seen(_ sheet: Sheet) -> Sheet {
        underlayShow ? backed(sheet) : sheet
    }

    func exported(_ sheet: Sheet) -> Sheet {
        underlayExport ? backed(sheet) : sheet
    }

    func absorb(_ list: [Material]) {
        let old = Set(extra.map(\.code))
        material?.pack.materials.removeAll { old.contains($0.code) }
        for code in old { ci?.pack.tints[code] = nil }
        extra = list.filter { item in material?.pack.material(item.code) == nil && ci?.pack.tints[item.code] == nil }
        material?.pack.materials += extra
        for item in extra { ci?.pack.tints[item.code] = item.tone }
    }

    func attach(_ urls: [URL]) {
        for url in urls {
            guard !attachments.contains(where: { $0.name == url.lastPathComponent }) else { continue }
            guard let data = try? Data(contentsOf: url) else { continue }
            let ext = url.pathExtension.lowercased()
            let item: Attachment
            if let role = Self.sheets[ext] {
                item = Attachment(name: url.lastPathComponent, data: data, mediaType: Attachment.text, role: role)
            } else if let type = UTType(filenameExtension: ext)?.preferredMIMEType {
                item = Attachment(name: url.lastPathComponent, data: data, mediaType: type)
            } else {
                continue
            }
            if item.supported { attachments.append(item) } else { failure = "\(DesignError.unsupported(item.name))" }
        }
    }

    func role(_ name: String, _ next: Attachment.Role) {
        guard let index = attachments.firstIndex(where: { $0.name == name }) else { return }
        attachments[index].role = next
        if underlay == name, !choices.contains(where: { $0.name == name }) { underlay = nil }
    }

    func pick(_ kind: Source) {
        source = kind
        guard kind != .text else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = kind == .pdf ? [.pdf] + Self.sheets.keys.sorted().compactMap { UTType(filenameExtension: $0) } : [.png, .jpeg, .gif, .webP]
        if panel.runModal() == .OK { attach(panel.urls) }
    }

    func detach(_ name: String) {
        attachments.removeAll { $0.name == name }
        if underlay == name { underlay = nil }
    }

    func design() {
        guard !designing else { return }
        let request = Brief(text: brief, attachments: attachments, current: parts,
                            materials: ci.map { Array($0.pack.tints.keys) } ?? [],
                            catalog: material?.pack.materials.map(\.code) ?? [])
        let snapshot = parts
        let title = brief.split(separator: "\n").first.map(String.init) ?? objectName
        designing = true
        failure = nil
        Task {
            defer { designing = false }
            do {
                let proposal = try await designer.design(request)
                guard parts == snapshot else { throw DesignError.stale }
                let known = Set(snapshot.map(\.id))
                ready = false
                if proposal.parts.contains(where: { known.contains($0.id) }) {
                    project.merge(proposal.project) { _, new in new }
                } else {
                    project = proposal.project
                }
                adopt()
                absorb(proposal.materials)
                parts = proposal.parts
                variants = proposal.variants
                assumptions = proposal.assumptions
                questions = proposal.questions
                objectName = title
                hidden = []
                accent = nil
                if let first = proposal.products.first, let kind = Kind(rawValue: first) { layout = kind }
                rebuild()
                ready = true
                assistant = false
                render()
            } catch {
                failure = "\(error)"
            }
        }
    }
}
