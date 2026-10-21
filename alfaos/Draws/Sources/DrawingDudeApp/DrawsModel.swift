import AppKit
import DrawingKit
import DrawsAI
import DrawsFonts
import Foundation
import Observation
import UniformTypeIdentifiers

enum Kind: String, CaseIterable {
    case presentation, plan, iso, steps, customer

    var product: Product {
        switch self {
        case .presentation: return .presentation
        case .plan: return .plan
        case .iso: return .iso(ViewSpec(kind: .iso))
        case .steps: return .steps(ViewSpec(kind: .iso), [])
        case .customer: return .customer(ViewSpec(kind: .iso))
        }
    }
}

@MainActor
@Observable
final class DrawsModel {
    var objectName = ""
    var parts: [Part] = []
    var project: [String: String] = [:]
    var ci: Loaded<CIPack>?
    var template: Loaded<TemplatePack>?
    var material: Loaded<MaterialPack>?
    var layout = Kind.presentation
    var dimensions = true
    var outline = true { didSet { render() } }
    var shadow = true { didSet { render() } }
    var accent: String? { didSet { render() } }
    var pages: [Sheet] = []
    var page = 0
    var failure: String?
    var brief = ""
    var attachments: [Attachment] = []
    var designing = false
    var assumptions: [String] = []
    var questions: [String] = []
    var variants: [Variant] = []
    private let designer: Designer = ClaudeDesigner()

    func attach(_ urls: [URL]) {
        for url in urls {
            guard !attachments.contains(where: { $0.name == url.lastPathComponent }) else { continue }
            guard let data = try? Data(contentsOf: url),
                  let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType else { continue }
            let item = Attachment(name: url.lastPathComponent, data: data, mediaType: type)
            if item.supported { attachments.append(item) } else { failure = "\(DesignError.unsupported(item.name))" }
        }
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
                if let first = proposal.products.first, let kind = Kind(rawValue: first) { layout = kind }
                render()
            } catch {
                failure = "\(error)"
            }
        }
    }

    var sheet: Sheet? { pages.indices.contains(page) ? pages[page] : nil }

    func turn(_ step: Int) {
        page = min(max(0, page + step), max(0, pages.count - 1))
    }

    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    var defects: [String] {
        (ci?.defects ?? []) + (template?.defects ?? []) + (material?.defects ?? []) + (sheet?.defects ?? [])
    }

    func start() {
        do {
            ci = try Packs.loadCI(Self.root.appendingPathComponent("Packs/ci/platzhalter"))
            template = try Packs.loadTemplate(Self.root.appendingPathComponent("Packs/template/a3-quer"))
            material = try Packs.loadMaterial(Self.root.appendingPathComponent("Packs/material/platzhalter"))
            load(Self.root.appendingPathComponent("Examples/kueche.json"))
        } catch {
            failure = "\(error)"
        }
    }

    func load(_ url: URL) {
        do {
            let object = try DrawingObject.load(url)
            try Validate.parts(object.parts)
            parts = object.parts
            project = object.project ?? [:]
            variants = object.variants ?? []
            objectName = url.deletingPathExtension().lastPathComponent
            render()
        } catch {
            failure = "\(error)"
        }
    }

    func render() {
        guard let ci, let template else { return }
        var style = ci.pack.iso
        if !outline { style.outline = 0 }
        if !shadow { style.shadow = 0 }
        style.accent = accent
        do {
            pages = try DrawingEngine.render(Job(parts: parts, ci: ci.pack, template: template.pack, project: project,
                                                 products: [layout.product], style: style, dimensions: dimensions,
                                                 material: material?.pack, variants: variants, dims: dimensions ? .given : .none,
                                                 fonts: DrawsFonts.fallback))
            page = min(page, max(0, pages.count - 1))
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

    func export(pdf: Bool) {
        guard let sheet else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [pdf ? .pdf : .svg]
        panel.nameFieldStringValue = "\(objectName)-\(layout.rawValue).\(pdf ? "pdf" : "svg")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try (pdf ? SheetExporter.pdf(pages) : SheetExporter.svg(sheet)).write(to: url)
        } catch {
            failure = "\(error)"
        }
    }
}
