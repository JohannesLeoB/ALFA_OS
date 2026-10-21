import AppKit
import DrawingKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class DrawsModel {
    var objectName = ""
    var parts: [Part] = []
    var project: [String: String] = [:]
    var ci: Loaded<CIPack>?
    var template: Loaded<TemplatePack>?
    var layout = SheetLayout.threeView
    var dimensions = true
    var sheet: Sheet?
    var failure: String?

    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    var defects: [String] {
        (ci?.defects ?? []) + (template?.defects ?? []) + (sheet?.defects ?? [])
    }

    func start() {
        do {
            ci = try Packs.loadCI(Self.root.appendingPathComponent("Packs/ci/platzhalter"))
            template = try Packs.loadTemplate(Self.root.appendingPathComponent("Packs/template/a3-quer"))
            load(Self.root.appendingPathComponent("Examples/kueche.json"))
        } catch {
            failure = "\(error)"
        }
    }

    func load(_ url: URL) {
        do {
            let object = try DrawingObject.load(url)
            parts = object.parts
            project = object.project ?? [:]
            objectName = url.deletingPathExtension().lastPathComponent
            render()
        } catch {
            failure = "\(error)"
        }
    }

    func render() {
        guard let ci, let template else { return }
        do {
            sheet = try DrawingEngine.render(Request(parts: parts, ci: ci.pack, template: template.pack,
                                                     project: project, layout: layout, dimensions: dimensions))
            failure = nil
        } catch {
            sheet = nil
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
            try (pdf ? SheetExporter.pdf(sheet) : SheetExporter.svg(sheet)).write(to: url)
        } catch {
            failure = "\(error)"
        }
    }
}
