import CoreGraphics
import DrawingKit
import DrawsFonts
import Foundation
import Pages

func runCatalog(_ args: [String]) {
    func value(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    guard let source = value("--catalog"), let target = value("--out"), let size = value("--page") else {
        fail("usage: drawingdude --catalog spec.json --page 841x594 --cols 6 --out x.pdf [--svg x.svg] [--png x.png] [--packs <folder>] [--fonts <folder>]")
    }
    let dims = size.split(separator: "x").compactMap { Double($0) }
    guard dims.count == 2, dims.allSatisfy({ $0 > 0 }) else { fail("bad --page \(size)") }
    guard let cols = value("--cols").flatMap(Int.init), cols > 0 else { fail("bad --cols") }
    let packs = URL(fileURLWithPath: value("--packs") ?? "Packs", isDirectory: true)
    do {
        let spec = try JSONDecoder().decode(KitchenSpec.self, from: Data(contentsOf: URL(fileURLWithPath: source)))
        let pack = try KitchenPack.load(packs.appendingPathComponent("presets/carcass.json"))
        let ciFolder = packs.appendingPathComponent("ci/platzhalter", isDirectory: true)
        let ci = try Packs.loadCI(ciFolder)
        let template = try Packs.loadTemplate(packs.appendingPathComponent("template/a3-quer", isDirectory: true), also: [ciFolder])
        let defects = ci.defects + template.defects
        if !defects.isEmpty { fail("pack defects: " + defects.joined(separator: ", ")) }
        let fonts = DrawsFonts.resolve(upload: value("--fonts").map { URL(fileURLWithPath: $0, isDirectory: true) })
        let entries = try Catalog.entries(spec, pack: pack)
        let sheet = try Catalog.sheet(entries, ci: ci.pack, template: template.pack, fonts: fonts,
                                      page: CGSize(width: dims[0], height: dims[1]), cols: cols)
        try SheetExporter.pdf(sheet).write(to: URL(fileURLWithPath: target))
        if let path = value("--svg") { try SheetExporter.svg(sheet).write(to: URL(fileURLWithPath: path)) }
        if let path = value("--png") {
            guard let png = BitmapRenderer(paper: sheet.paper, dpi: 150).render(sheet.document).first else { fail("error: no png") }
            try png.write(to: URL(fileURLWithPath: path))
        }
        print("\(target): \(entries.count) cabinets, 1:\(Int(sheet.scale))")
    } catch {
        fail("error: \(error)")
    }
}
