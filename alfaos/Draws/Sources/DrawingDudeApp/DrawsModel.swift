import AppKit
import Assist
import CoreGraphics
import DrawingKit
import DrawsAI
import DrawsDock
import DrawsFonts
import DrawsRender
import Foundation
import Observation
import ShellCore
import UniformTypeIdentifiers

enum Kind: String, CaseIterable {
    case plan, iso, steps, perspective, customer, presentation, cover
}

enum Tab: String, CaseIterable { case view, style, render, export }

enum Fill: String, CaseIterable { case tone, material }

enum Format: String, CaseIterable {
    case pdf, svg, html

    var type: UTType {
        switch self {
        case .pdf: .pdf
        case .svg: .svg
        case .html: .html
        }
    }

    var save: String {
        switch self {
        case .pdf: "draws.export.savePDF"
        case .svg: "draws.export.saveSVG"
        case .html: "draws.export.saveHTML"
        }
    }
}

enum Source: String, CaseIterable { case photo, pdf, text }

enum Approach: String, CaseIterable { case once, live }

enum Phase: String { case run, ok, error }

enum Ending: String { case done, stopped, failed }

struct Move: Identifiable {
    let id: Int
    let tool: String
    var phase: Phase
}

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
    var units: [DrawingKit.Unit] = [] { didSet { render() } }
    var pose: [String: Double] = [:] { didSet { render() } }
    var active: String?
    var claudeModel: String?
    var selected: String?
    var kitchen: KitchenSpec?
    var chosen: [Locus] = []
    var history: [KitchenSpec] = []
    var future: [KitchenSpec] = []
    var photoStale = false
    var kitchenPack: KitchenPack?
    var editing: Editing?
    var toolbox: DrawsToolbox?
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
    var format = Format.pdf
    var allPages = true
    var assistant = false
    var source = Source.text
    var pages: [Sheet] = []
    var page = 0
    var failure: String?
    var overflow = false
    var brief = ""
    var attachments: [Attachment] = [] { didSet { touch() } }
    var designing = false
    var approach = Approach.once
    var running = false
    var moves: [Move] = []
    var voice = ""
    var steer = ""
    var ending: Ending?
    var assumptions: [String] = []
    var questions: [String] = []
    var variants: [Variant] = []
    var blocks: [Panel] = []
    var choice = ""
    var presets: [PromptPreset] = []
    var extra: [Material] = []
    var look = Look() { didSet { touch() } }
    var photo: CGImage?
    var rendering = false
    var photoFailure: String?
    var underlayShow = false { didSet { touch() } }
    var underlayExport = false { didSet { touch() } }
    private(set) var underlayData: Data?
    var underlay: String? {
        didSet {
            underlayData = underlay.flatMap { name in choices.first { $0.name == name } }
                .flatMap { Prepare.underlay($0, side: Proto.underlaySide) }
            touch()
        }
    }
    var ready = false
    var fileURL: URL?
    var dirty = false { didSet { NSApplication.shared.windows.first?.isDocumentEdited = dirty } }
    var ciID = ""
    var materialID = ""
    var styleID = "studio"
    private let designer: Designer
    @ObservationIgnored private var glide: Task<Void, Never>?
    @ObservationIgnored private var chat: Session?

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

    var images: [String: Data] {
        Dictionary(attachments.filter { $0.role == .material && Attachment.images.contains($0.mediaType) }.map { ($0.name, $0.data) },
                   uniquingKeysWith: { first, _ in first })
    }

    var codes: [String] {
        Array(Set(parts.map(\.material)).union(material?.pack.materials.map(\.code) ?? [])).sorted()
    }

    func materialName(_ code: String) -> String {
        material?.pack.material(code)?.name ?? code
    }

    func linked(_ image: String) -> String? {
        look.textures.sorted { $0.key < $1.key }.first { $0.value.image == image }?.key
    }

    func link(_ image: String, _ code: String?) {
        for key in look.textures.filter({ $0.value.image == image }).keys { look.textures[key] = nil }
        guard let code else { return }
        var next = look.textures[code] ?? Texture(image: image)
        next.image = image
        look.textures[code] = next
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

    var live: [DrawingKit.Unit] {
        let ids = Set(shown.map(\.id))
        return units.filter { ($0.front + $0.body).allSatisfy(ids.contains) }
    }

    var readouts: [Readout] {
        Readout.make(parts, units, amounts: pose)
    }

    func readout(_ id: String?) -> Readout? {
        id.flatMap { id in readouts.first { $0.unit == id } }
    }

    func label(_ unit: String) -> String {
        let names = units.first { $0.id == unit }?.front.compactMap { id in parts.first { $0.id == id }?.name } ?? []
        return names.isEmpty ? unit : names.joined(separator: ", ")
    }

    func swing(_ id: String) {
        active = id
        glide?.cancel()
        let start = pose[id] ?? 0, target = start > 0.5 ? 0.0 : 1.0, steps = Proto.glideSteps
        glide = Task {
            for n in 1...steps {
                try? await Task.sleep(for: .seconds(Design.Duration.lane / Double(steps)))
                guard !Task.isCancelled else { return }
                pose[id] = n == steps ? target : start + (target - start) * Double(n) / Double(steps)
            }
        }
    }

    func shift(_ id: String, _ value: Double) {
        glide?.cancel()
        active = id
        pose[id] = min(1, max(0, value))
    }

    func replace(units next: [DrawingKit.Unit]) {
        glide?.cancel()
        pose = [:]
        active = nil
        units = next
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

    var room: CGRect? {
        guard let t = template?.pack, var room = field else { return nil }
        if let deck = t.deck { room.size.height -= deck.captionGap + 2 * deck.captionLeading }
        return room
    }

    func preset() -> [Cell] {
        guard let t = template?.pack, let room else { return [] }
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
            ciID = dock.templates.packs(.ci).first?.name ?? ""
            materialID = dock.templates.packs(.material).first?.name ?? ""
            fonts = DrawsFonts.resolve(upload: dock.templates.fonts())
            guard ci != nil, template != nil else {
                failure = word("dock.reason.packs")
                return
            }
            presets = PromptPresets.load(Self.root.appendingPathComponent("Packs/presets/default.json"))
            kitchenPack = try? KitchenPack.load(Self.root.appendingPathComponent("Packs/presets/carcass.json"))
            resetStyle()
            cells = preset()
            ready = true
            load(Self.root.appendingPathComponent("Examples/kueche.json"))
        } catch {
            failure = "\(error)"
        }
    }

    func touch() {
        if ready { dirty = true }
    }

    func choose(_ ref: PackRef) {
        do {
            let next = try dock.loadTemplate(ref)
            let cis = dock.templates.packs(.ci)
            ciID = (cis.first { $0.name == next.pack.ciName } ?? cis.first)?.name ?? ""
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
            try Validate.units(object.units ?? [], parts: object.parts)
            ready = false
            kitchen = nil
            forgetCabinets()
            parts = object.parts
            replace(units: object.units ?? [])
            project = object.project ?? [:]
            adopt()
            variants = object.variants ?? []
            blocks = object.blocks ?? []
            hidden = []
            accent = nil
            rebuild()
            objectName = url.deletingPathExtension().lastPathComponent
            fileURL = nil
            ready = true
            render()
            dirty = false
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
        if case .ready(let name) = dock.claude.readiness() { claudeModel = name } else { claudeModel = nil }
    }

    func saveClaude(key: String, name: String) -> Bool {
        do {
            try dock.claude.connect(key: key, model: name)
            checkDock()
            return true
        } catch {
            failure = "\(error)"
            return false
        }
    }

    func clear() {
        ready = false
        kitchen = nil
        forgetCabinets()
        parts = []
        replace(units: [])
        blocks = []
        hidden = []
        accent = nil
        rebuild()
        objectName = ""
        fileURL = nil
        ready = true
        render()
        dirty = false
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
        touch()
        guard ready, let ci, let template else { return }
        overflow = false
        guard !shown.isEmpty else {
            pages = []
            failure = nil
            return
        }
        do {
            pages = try DrawingEngine.render(makeJob(ci, template))
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

    private func makeJob(_ ci: Loaded<CIPack>, _ template: Loaded<TemplatePack>) -> Job {
        let running = live, ids = Set(running.map(\.id))
        return Job(parts: shown, ci: ci.pack, template: template.pack, project: project,
                   products: [product()], style: style(), dimensions: dimensions,
                   material: material?.pack, variants: variants, dims: dimensions ? .given : .none,
                   fonts: fonts, blocks: blocks, units: running,
                   pose: pose.filter { ids.contains($0.key) })
    }

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.svg, .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if url.pathExtension.lowercased() == "json" { load(url) } else { drop([url]) }
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
        panel.allowedContentTypes = [format.type]
        panel.nameFieldStringValue = fileName(format.rawValue)
        panel.directoryURL = dock.destination(place, project: number)
        guard panel.runModal() == .OK, let url = panel.url, let data = payload(sheet) else { return }
        send(Deliverable(name: url.lastPathComponent, mimeType: format.type.preferredMIMEType ?? "", data: data,
                         folder: url.deletingLastPathComponent()), .save)
    }

    private func payload(_ sheet: Sheet) -> Data? {
        switch format {
        case .pdf:
            return SheetExporter.pdf(allPages ? pages.map(exported) : [exported(sheet)])
        case .svg:
            return SheetExporter.svg(exported(sheet))
        case .html:
            guard let ci, let template else { return nil }
            do {
                return Data(try SheetExporter.interactive(job: makeJob(ci, template)).utf8)
            } catch {
                failure = "\(error)"
                return nil
            }
        }
    }

    func renderPhoto() {
        guard !rendering, !shown.isEmpty else { return }
        let running = live, ids = Set(running.map(\.id))
        let posed = DrawingKit.pose(shown, running, amounts: pose.filter { ids.contains($0.key) })
        let kind = cell(selected)?.view ?? cells.first { $0.view == .iso || $0.view == .perspective }?.view ?? .iso
        let size = shown.reduce(0.0) { max($0, $1.w, $1.d, $1.h) }
        let view = ViewSpec(kind: kind, azimuth: azimuth, elevation: elevation, distance: kind == .perspective ? Proto.perspectiveDistance * size : nil)
        let surfaces = look.surfaces(images: images, tones: ci?.pack.tints ?? [:], codes: Array(Set(posed.map(\.material))))
        let scene = PhotoScene(parts: posed, surfaces: surfaces, light: look.light, view: view,
                               backdrop: Proto.photoBackdrop, margin: Proto.photoMargin)
        rendering = true
        photoFailure = nil
        Task {
            defer { rendering = false }
            do {
                photo = try await Photo.render(scene, width: Proto.photoWidth, height: Proto.photoHeight)
                photoStale = false
            } catch {
                photoFailure = word("draws.render.failed")
            }
        }
    }

    func photoName(_ ext: String) -> String {
        if let name = ExportName.make(project: project, number: number, trade: trade, variants: variants.map(\.name),
                                      now: Date(), ext: ext) {
            return name
        }
        let base = objectName.components(separatedBy: CharacterSet(charactersIn: "/:")).joined()
        return (base.isEmpty ? "" : "\(base)-") + "render.\(ext)"
    }

    func exportPhoto(_ pdf: Bool) {
        guard let photo else { return }
        let type: UTType = pdf ? .pdf : .png
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = photoName(pdf ? "pdf" : "png")
        panel.directoryURL = dock.destination(place, project: number)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = pdf ? try Photo.pdf(photo) : try Photo.png(photo)
            send(Deliverable(name: url.lastPathComponent, mimeType: type.preferredMIMEType ?? "", data: data,
                             folder: url.deletingLastPathComponent()), .save)
        } catch {
            failure = "\(error)"
        }
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
        if next == .material, linked(name) == nil, let data = images[name] {
            let tones = ci?.pack.tints ?? [:]
            if let code = Prepare.suggest(data, tones: tones, among: Set(parts.map(\.material)).sorted()) { link(name, code) }
        }
        if next != .material { link(name, nil) }
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
        link(name, nil)
        attachments.removeAll { $0.name == name }
        if underlay == name { underlay = nil }
    }

    func design() {
        guard !designing, !running else { return }
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
                kitchen = nil
            forgetCabinets()
                parts = proposal.parts
                replace(units: proposal.units)
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

    func draft() -> Draft {
        var next = Draft(parts: parts, units: units, pose: pose, layout: layout.rawValue, cells: cells, azimuth: azimuth,
              elevation: elevation, faces: faces, tone: fill == .tone, edge: edge, outline: outline,
              shadow: shadowOn ? shadow : 0, accent: accent, accentColor: accentColor, dimensions: dimensions)
        next.look = look
        next.kitchen = kitchen
        return next
    }

    func bench() -> Bench? {
        guard let ci, let template, let room else { return nil }
        let gap = template.pack.gap
        var bench = Bench(ci: ci.pack, template: template.pack, material: material?.pack, fonts: fonts, project: project,
                     variants: variants, blocks: blocks, kinds: kinds.map(\.rawValue), distance: Proto.perspectiveDistance,
                     dials: Dials(azimuth: Proto.azimuth.low...Proto.azimuth.high,
                                  elevation: Proto.elevation.low...Proto.elevation.high,
                                  edge: Proto.edge.low...Proto.edge.high, outline: Proto.outline.low...Proto.outline.high,
                                  shadow: Proto.shadow.low...Proto.shadow.high),
                     dpi: Proto.previewDPI,
                     preset: { name, list in
                         Presets.cells(Kind(rawValue: name) ?? .plan, field: room, gap: gap, steps: Set(list.map(\.z)).count)
                     })
        bench.kitchen = kitchenPack
        return bench
    }

    func apply(_ next: Draft) {
        let was = ready
        ready = false
        glide?.cancel()
        parts = next.parts
        units = next.units
        pose = next.pose
        active = nil
        hidden = hidden.filter { id in next.parts.contains { $0.id == id } }
        if let kind = Kind(rawValue: next.layout), kind != layout { layout = kind }
        cells = next.cells
        azimuth = next.azimuth
        elevation = next.elevation
        fill = next.tone ? .tone : .material
        faces = next.faces
        edge = next.edge
        outline = next.outline
        shadowOn = next.shadow > 0
        if next.shadow > 0 { shadow = next.shadow }
        accent = next.accent
        accentColor = next.accentColor
        dimensions = next.dimensions
        look = next.look
        kitchen = next.kitchen
        chosen = chosen.filter(live)
        photoStale = true
        ready = was
        render()
    }

    func startLive() {
        guard !running, !designing, let bench = bench() else { return }
        let packs = Self.root.appendingPathComponent("Packs")
        let master = try? StyleMaster.load(packs.appendingPathComponent("style/\(styleID).json"))
        let start = master.map { draft().seeded(by: $0, dials: bench.dials) } ?? draft()
        let keys = ["motion", "materials"] + (dimensions ? ["dims"] : []) + (dimensions || layout == .plan || layout == .steps ? ["plans"] : []) + (layout == .steps ? ["steps"] : [])
        let toolbox = DrawsToolbox(draft: start, bench: bench, images: images) { [weak self] next in self?.apply(next) }
        self.toolbox = toolbox
        editing = nil
        let session = Session(credentials: dock.claude.credentials, http: URLSession.shared)
        let text = brief, attached = attachments
        chat = session
        running = true
        failure = nil
        moves = []
        voice = ""
        ending = nil
        Task {
            defer {
                running = false
                chat = nil
                self.toolbox = nil
            }
            let folder = { (name: String, keys: [String]) in try? Skillset.load(packs.appendingPathComponent("skills/" + name), keys: keys) }
            guard let base = folder("alfanomy", keys), let cabinet = folder("cabinetclaude", ["types", "splits", "appliances", "variants"]) else {
                failure = word("draws.live.skills")
                ending = .failed
                return
            }
            let skills = base.merging(cabinet)
            let media = await Live.media(attached)
            let events = await session.run(prompt: text, media: media, toolbox: toolbox, skills: skills, style: master,
                                           budget: Budget(rounds: Proto.liveRounds, tokens: Proto.liveTokens))
            for await event in events { handle(event) }
        }
    }

    func stopLive() {
        guard let chat else { return }
        Task { await chat.stop() }
    }

    func send() {
        let text = steer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard running, !text.isEmpty, let chat else { return }
        steer = ""
        Task { await chat.say(text) }
    }

    private func handle(_ event: Event) {
        switch event {
        case .toolCall(let name, _):
            moves.append(Move(id: moves.count, tool: name, phase: .run))
        case .toolResult(let name, let ok, _):
            if let index = moves.lastIndex(where: { $0.tool == name && $0.phase == .run }) {
                moves[index].phase = ok ? .ok : .error
            }
        case .text(let text):
            voice = text
        case .finished(let done):
            voice = done.summary
            assumptions = done.assumptions
            questions = done.questions
            ending = .done
        case .stopped:
            ending = .stopped
        case .failed(let fault):
            failure = Self.reason(fault)
            ending = .failed
        case .thinking, .image:
            break
        }
    }

    private static func reason(_ fault: Fault) -> String {
        switch fault {
        case .noKey: return word("dock.reason.key")
        case .noModel: return word("dock.reason.model")
        case .emptyPrompt: return word("draws.live.empty")
        case .http(let code, _): return String(format: word("draws.live.http"), code)
        default: return word("draws.live.failed")
        }
    }
}
