import CoreGraphics
import Foundation
import Testing
@testable import DrawingKit
@testable import DrawsAI
import DrawsFonts

struct Case: Decodable { var name: String; var parts: [Part]; var project: [String: String]?; var products: [String]; var distance: Double?; var tints: [String: String]?; var variants: [Variant]?; var dims: DimMode?; var faces: [String]?; var accent: String?; var accentColor: String?; var scale: Double? }; struct Fixture: Decodable { var draw: [Case]; var replies: [String]; var packs: [String] }

@Test func drawsMatchesGolden() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../..").standardized
    let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: root.appending(path: "Fixtures/cases.json")))
    let ci = try Packs.loadCI(root.appending(path: "Packs/ci/platzhalter")), tpl = try Packs.loadTemplate(root.appending(path: "Packs/template/a3-quer")), mat = try Packs.loadMaterial(root.appending(path: "Packs/material/platzhalter"))
    var out = "packs \(ci.defects) \(tpl.defects) \(mat.defects) \(mat.pack.materials.count)\n" + fixture.packs.map { "\((try? Packs.decodeCI(Data($0.utf8)))?.defects ?? []) \((try? Packs.decodeTemplate(Data($0.utf8)))?.defects ?? []) \((try? Packs.decodeMaterial(Data($0.utf8)))?.defects ?? [])" }.joined(separator: "\n") + "\n"
    for c in fixture.draw {
        let pack = c.tints.map { t in var p = ci.pack; p.tints.merge(t) { $1 }; return p } ?? ci.pack
        let job = Job(parts: c.parts, ci: pack, template: tpl.pack, project: c.project ?? [:], products: c.products.compactMap { Product.named($0, distance: c.distance) }, style: c.faces.map { var s = pack.iso; s.faces = $0; s.accent = c.accent; s.accentColor = c.accentColor; return s }, material: mat.pack, variants: c.variants ?? [], dims: c.dims ?? .none, fonts: DrawsFonts.fallback, scale: c.scale)
        do { let s = try DrawingEngine.render(job); out += "## \(c.name) pages \(CGDataProvider(data: SheetExporter.pdf(s) as CFData).flatMap(CGPDFDocument.init)?.numberOfPages ?? 0)\n" + s.map { "\($0.product) \($0.defects)\n" + String(decoding: SheetExporter.svg($0), as: UTF8.self) }.joined(separator: "\n") + "\n" } catch { out += "## \(c.name) error \(error)\n" }
    }
    let request = try ClaudeDesigner().request(Brief(text: "Kitchen", attachments: [Attachment(name: "a.png", data: Data([1]), mediaType: "image/png"), Attachment(name: "b.pdf", data: Data([2]), mediaType: "application/pdf")], materials: ["platte", "korpus"], catalog: mat.pack.materials.map(\.code)), key: "k", model: "test-model")
    out += "\((request.allHTTPHeaderFields ?? [:]).sorted { $0.key < $1.key })\n" + String(decoding: request.httpBody ?? Data(), as: UTF8.self) + "\n"
    out += "\([429, 529, 500, 400].map(ClaudeDesigner.retryable)) \([ClaudeDesigner.delay(attempt: 0, retryAfter: "90"), ClaudeDesigner.delay(attempt: 1, retryAfter: nil)]) \(ClaudeDesigner.failure(400, "{\"error\":\"output_config.format not supported\"}", model: "m")) \(ClaudeDesigner.failure(400, "bad", model: "m"))\n"
    for reply in fixture.replies {
        do { let p = try ClaudeDesigner.proposal(from: Data(reply.utf8), materials: ["korpus", "platte"], catalog: mat.pack.materials.map(\.code)); out += "\(p.parts) \(p.project.sorted { $0.key < $1.key }) \(p.products) \(p.assumptions) \(p.questions) \(p.variants.map { "\($0.id) \($0.name) \($0.slots.sorted { $0.key < $1.key })" })\n" } catch { out += "error \(error)\n" }
    }
    let golden = root.appending(path: "Fixtures/golden.txt")
    if ProcessInfo.processInfo.environment["DRAWS_GOLDEN"] != nil { try out.write(to: golden, atomically: true, encoding: .utf8) }
    #expect(out == (try String(contentsOf: golden, encoding: .utf8)))
}
