import DrawingKit
import Foundation

func fail(_ text: String) -> Never {
    FileHandle.standardError.write(Data((text + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.first == "render", args.count >= 2 else {
    fail("usage: drawingdude render object.json --ci <folder> --template <folder> --out <folder>")
}
func option(_ name: String) -> String {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { fail("missing \(name)") }
    return args[i + 1]
}
let objectURL = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: option("--out"), isDirectory: true)

do {
    let object = try DrawingObject.load(objectURL)
    let ci = try Packs.loadCI(URL(fileURLWithPath: option("--ci"), isDirectory: true))
    let template = try Packs.loadTemplate(URL(fileURLWithPath: option("--template"), isDirectory: true))
    let defects = ci.defects + template.defects
    if !defects.isEmpty { fail("pack defects: " + defects.joined(separator: ", ")) }
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let names: [SheetLayout: String] = [.threeView: "blatt1-dreiseiten", .iso: "blatt2-iso"]
    for layout in SheetLayout.allCases {
        let request = Request(parts: object.parts, ci: ci.pack, template: template.pack,
                              project: object.project ?? [:], layout: layout)
        let sheet = try DrawingEngine.render(request)
        let name = names[layout] ?? layout.rawValue
        try SheetExporter.svg(sheet).write(to: out.appendingPathComponent(name + ".svg"))
        try SheetExporter.pdf(sheet).write(to: out.appendingPathComponent(name + ".pdf"))
        let note = sheet.defects.isEmpty ? "" : "  defects: " + sheet.defects.joined(separator: ", ")
        print("\(name): A\(template.pack.format.dropFirst()) \(Int(sheet.width))x\(Int(sheet.height)) mm, 1:\(Int(sheet.scale))\(note)")
    }
} catch let error as DrawingError {
    fail("error: \(error)")
} catch {
    fail("error: \(error.localizedDescription)")
}
