import DrawingKit
import DrawsFonts
import Foundation

func fail(_ text: String) -> Never {
    FileHandle.standardError.write(Data((text + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.first == "render", args.count >= 2 else {
    fail("usage: drawingdude render object.json --ci <folder> --template <folder> --out <folder> [--material <folder>] [--dims none|given] [--fonts <folder>] [--products presentation,plan,iso,perspective,steps,customer] [--distance <mm>]")
}
func option(_ name: String) -> String {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { fail("missing \(name)") }
    return args[i + 1]
}
func optional(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}
let distance = optional("--distance").flatMap(Double.init).flatMap { $0 > 0 ? $0 : nil }
func product(_ name: String) -> Product {
    if name == "perspective", distance == nil { fail("missing --distance") }
    guard let product = Product.named(name, distance: distance) else { fail("unknown product \(name)") }
    return product
}
func dimMode(_ name: String) -> DimMode {
    guard let mode = DimMode(rawValue: name) else { fail("unknown dims \(name)") }
    return mode
}
let dims = optional("--dims").map(dimMode) ?? .none
let products = (optional("--products") ?? "plan,iso").split(separator: ",").map { product(String($0)) }
let objectURL = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: option("--out"), isDirectory: true)

do {
    let object = try DrawingObject.load(objectURL)
    let ci = try Packs.loadCI(URL(fileURLWithPath: option("--ci"), isDirectory: true))
    let template = try Packs.loadTemplate(URL(fileURLWithPath: option("--template"), isDirectory: true))
    let upload = optional("--fonts").map { URL(fileURLWithPath: $0, isDirectory: true) }
    if let upload, SheetFonts.upload(upload) == nil { fail("no fonts in \(upload.path)") }
    let material = try optional("--material").map { try Packs.loadMaterial(URL(fileURLWithPath: $0, isDirectory: true)) }
    let defects = ci.defects + template.defects + (material?.defects ?? [])
    if !defects.isEmpty { fail("pack defects: " + defects.joined(separator: ", ")) }
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let job = Job(parts: object.parts, ci: ci.pack, template: template.pack,
                  project: object.project ?? [:], products: products,
                  material: material?.pack, variants: object.variants ?? [], dims: dims,
                  fonts: DrawsFonts.resolve(upload: upload))
    let sheets = try DrawingEngine.render(job)
    for (index, sheet) in sheets.enumerated() {
        let number = String(format: "%02d", index + 1)
        try SheetExporter.svg(sheet).write(to: out.appendingPathComponent("\(number)-\(sheet.product).svg"))
        let note = sheet.defects.isEmpty ? "" : "  defects: " + sheet.defects.joined(separator: ", ")
        print("\(number)-\(sheet.product): A\(template.pack.format.dropFirst()) \(Int(sheet.width))x\(Int(sheet.height)) mm, 1:\(Int(sheet.scale))\(note)")
    }
    try SheetExporter.pdf(sheets).write(to: out.appendingPathComponent("set.pdf"))
} catch let error as DrawingError {
    fail("error: \(error)")
} catch {
    fail("error: \(error.localizedDescription)")
}
