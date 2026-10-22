import DrawingKit
import DrawsFonts
import Foundation

func runDoc(_ args: [String]) {
    func value(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    guard let target = value("--out") else { fail("usage: drawingdude --doc case.json --out x.svg | --open x.svg --out y.svg [--packs <folder>] [--fonts <folder>]") }
    let packs = URL(fileURLWithPath: value("--packs") ?? "Packs", isDirectory: true)
    let upload = value("--fonts").map { URL(fileURLWithPath: $0, isDirectory: true) }
    do {
        let doc: DrawsDoc
        if let path = value("--doc") {
            doc = try JSONDecoder().decode(DrawsDoc.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        } else if let path = value("--open") {
            guard let read = try DocFile.read(Data(contentsOf: URL(fileURLWithPath: path))) else { fail("error: no draws document in \(path)") }
            doc = read
        } else {
            fail("missing --doc or --open")
        }
        let data = try DocFile.svg(doc, shelf: PackShelf(root: packs), fonts: DrawsFonts.resolve(upload: upload))
        try data.write(to: URL(fileURLWithPath: target))
        print("\(target): \(data.count) bytes, \(doc.parts.count) parts, \(doc.inputs.count) inputs")
    } catch {
        fail("error: \(error)")
    }
}
