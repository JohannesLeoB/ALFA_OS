import DrawingKit
import DrawsFonts
import Foundation
import Pages

@MainActor
func runKitchen(_ args: [String]) async {
    func value(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    guard let source = value("--kitchen"), let target = value("--out") else {
        fail("usage: drawingdude --kitchen spec.json --out x.png|x.svg|x.pdf [--photo] [--open 0...1] [--products iso,plan] [--packs <folder>] [--view <kind>] [--size 1600x1000] [--backdrop] [--light <preset>] [--azimuth <deg>] [--elevation <deg>]")
    }
    let packs = URL(fileURLWithPath: value("--packs") ?? "Packs", isDirectory: true)
    let ext = URL(fileURLWithPath: target).pathExtension.lowercased()
    guard ["png", "svg", "pdf"].contains(ext) else { fail("--out must end in png, svg or pdf") }
    do {
        let spec = try JSONDecoder().decode(KitchenSpec.self, from: Data(contentsOf: URL(fileURLWithPath: source)))
        let pack = try KitchenPack.load(packs.appendingPathComponent("presets/carcass.json"))
        let built = try Kitchen.generate(spec, pack: pack)
        var amounts: [String: Double] = [:]
        if let open = value("--open") {
            guard let amount = Double(open), (0...1).contains(amount) else { fail("bad --open \(open)") }
            for unit in built.units where unit.kind == .drawer { amounts[unit.id] = amount }
        }
        if args.contains("--photo") {
            var more = args
            if !amounts.isEmpty, value("--pose") == nil {
                more += ["--pose", amounts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")]
            }
            if value("--ci") == nil { more += ["--ci", packs.appendingPathComponent("ci/platzhalter").path] }
            if ext == "pdf", value("--pdf") == nil { more += ["--pdf", target] }
            await runPhoto(more, kitchen: (DrawingObject(parts: built.parts, units: built.units), pack.tints))
            return
        }
        let extra = pack.tints.sorted { $0.key < $1.key }.map { Material(code: $0.key, name: $0.key, tone: $0.value, status: "") }
        let names = (value("--products") ?? "iso,plan").split(separator: ",").map(String.init)
        let fonts = DrawsFonts.resolve(upload: value("--fonts").map { URL(fileURLWithPath: $0, isDirectory: true) })
        let shelf = PackShelf(root: packs)
        var sheets: [Sheet] = []
        for name in names {
            let doc = DrawsDoc(parts: built.parts, packs: DocPacks(ci: "platzhalter", template: "a3-quer", material: "platzhalter"),
                               units: built.units, pose: amounts, extra: extra, render: DocRender(layout: name), kitchen: spec)
            sheets += try shelf.sheets(doc, fonts: fonts)
        }
        guard !sheets.isEmpty else { fail("error: no sheets") }
        let url = URL(fileURLWithPath: target)
        if ext == "pdf" {
            try SheetExporter.pdf(sheets).write(to: url)
        } else {
            for (index, sheet) in sheets.enumerated() {
                let file = index == 0 ? url : url.deletingLastPathComponent().appendingPathComponent(
                    url.deletingPathExtension().lastPathComponent + "-\(index + 1)." + ext)
                if ext == "svg" {
                    try SheetExporter.svg(sheet).write(to: file)
                } else if let png = BitmapRenderer(paper: sheet.paper, dpi: 150).render(sheet.document).first {
                    try png.write(to: file)
                }
            }
        }
        print("\(target): \(built.parts.count) parts, \(built.units.count) units, \(sheets.count) sheets")
    } catch {
        fail("error: \(error)")
    }
}
