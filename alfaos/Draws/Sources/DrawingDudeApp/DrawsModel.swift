import AppKit
import DrawingKit
import DrawsAI
import DrawsFonts
import Foundation
import Observation
import ShellCore
import UniformTypeIdentifiers

enum Kind: String, CaseIterable {
    case plan, iso, steps, perspective, customer, presentation
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
    var ci: Loaded<CIPack>?
    var template: Loaded<TemplatePack>?
    var material: Loaded<MaterialPack>?
    var layout = Kind.plan {
        didSet {
            let was = ready
            ready = false
            fill = layout == .customer || layout == .presentation ? .material : .tone
            fixed = nil
            page = 0
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
    var fixed: Double? { didSet { render() } }
    var focus: String? { didSet { render() } }
    var hidden: Set<String> = [] { didSet { render() } }
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
    private var ready = false
    private let designer: Designer = ClaudeDesigner()

    var sheet: Sheet? { pages.indices.contains(page) ? pages[page] : nil }

    var shown: [Part] {
        parts.filter { !hidden.contains($0.id) && (focus == nil || $0.id == focus) }
    }

    var missing: [String] {
        Self.fields.filter { (project[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var defects: [String] {
        (ci?.defects ?? []) + (template?.defects ?? []) + (material?.defects ?? []) + (sheet?.defects ?? [])
    }

    var scales: [Double] {
        guard let t = template?.pack else { return [] }
        let list = layout == .plan || layout == .presentation ? t.scales : t.isoScales
        return list.sorted()
    }

    func turn(_ step: Int) {
        page = min(max(0, page + step), max(0, pages.count - 1))
    }

    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func start() {
        do {
            ci = try Packs.loadCI(Self.root.appendingPathComponent("Packs/ci/platzhalter"))
            template = try Packs.loadTemplate(Self.root.appendingPathComponent("Packs/template/a3-quer"))
            material = try Packs.loadMaterial(Self.root.appendingPathComponent("Packs/material/platzhalter"))
            resetStyle()
            ready = true
            load(Self.root.appendingPathComponent("Examples/kueche.json"))
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
            variants = object.variants ?? []
            hidden = []
            focus = nil
            accent = nil
            fixed = nil
            objectName = url.deletingPathExtension().lastPathComponent
            ready = true
            render()
        } catch {
            failure = "\(error)"
        }
    }

    func clear() {
        ready = false
        parts = []
        hidden = []
        focus = nil
        accent = nil
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
        let spec = ViewSpec(kind: .iso, azimuth: azimuth, elevation: elevation)
        switch layout {
        case .plan: return .plan
        case .iso: return .iso(spec)
        case .steps: return .steps(spec, [])
        case .customer: return .customer(spec)
        case .presentation: return .presentation
        case .perspective:
            let size = shown.reduce(0.0) { max($0, $1.w, $1.d, $1.h) }
            return .iso(ViewSpec(kind: .perspective, azimuth: azimuth, elevation: elevation,
                                 distance: Proto.perspectiveDistance * size))
        }
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
                                                 fonts: DrawsFonts.fallback, scale: fixed))
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

    func export() {
        guard let sheet else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [pdf ? .pdf : .svg]
        let base = objectName.components(separatedBy: CharacterSet(charactersIn: "/:")).joined()
        panel.nameFieldStringValue = (base.isEmpty ? "" : "\(base)-") + "\(layout.rawValue).\(pdf ? "pdf" : "svg")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try (pdf ? SheetExporter.pdf(allPages ? pages : [sheet]) : SheetExporter.svg(sheet)).write(to: url)
        } catch {
            failure = "\(error)"
        }
    }

    func attach(_ urls: [URL]) {
        for url in urls {
            guard !attachments.contains(where: { $0.name == url.lastPathComponent }) else { continue }
            guard let data = try? Data(contentsOf: url),
                  let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType else { continue }
            let item = Attachment(name: url.lastPathComponent, data: data, mediaType: type)
            if item.supported { attachments.append(item) } else { failure = "\(DesignError.unsupported(item.name))" }
        }
    }

    func pick(_ kind: Source) {
        source = kind
        guard kind != .text else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = kind == .pdf ? [.pdf] : [.png, .jpeg, .gif, .webP]
        if panel.runModal() == .OK { attach(panel.urls) }
    }

    func detach(_ name: String) {
        attachments.removeAll { $0.name == name }
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
                parts = proposal.parts
                variants = proposal.variants
                assumptions = proposal.assumptions
                questions = proposal.questions
                objectName = title
                hidden = []
                focus = nil
                accent = nil
                if let first = proposal.products.first, let kind = Kind(rawValue: first) { layout = kind }
                ready = true
                assistant = false
                render()
            } catch {
                failure = "\(error)"
            }
        }
    }
}
