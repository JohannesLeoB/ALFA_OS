import Foundation
import ALFAcolorCore
import Document

/// Turns the placed items into manifest entries and the files they need: code files and own images.
struct MockupEntries {
    private let document: ALFAcolorDocument
    private let plan: MockupPlan
    private var tokens: MockupTokenUse
    private(set) var entries: [MockupManifest.Entry] = []
    /// Package path to bytes.
    private(set) var files: [String: Data] = [:]
    private(set) var warnings: [String] = []

    init(document: ALFAcolorDocument, plan: MockupPlan) {
        self.document = document
        self.plan = plan
        self.tokens = MockupTokenUse(sets: document.tokenSets)
    }

    func tokenData() throws -> Data {
        try tokens.json()
    }

    mutating func add(_ placed: MockupPlan.Placed) {
        let item = placed.item
        let box = plan.position(of: placed)
        var entry = MockupManifest.Entry(
            id: item.id.raw, type: "", title: item.title, frame: placed.frame?.id.raw,
            x: box.x, y: box.y, width: box.w, height: box.h, z: item.z)
        entry.layer = item.layerID

        switch item.content {
        case .code(let language, let sources, let previewWidth):
            let names = Self.orderedNames(sources.keys)
            let stem = Self.safeName(item.id.raw)
            // All files of the card share one folder, so that links between them still work.
            // The entry file is the one named index.html, else the first HTML file, else the first file.
            let main = names.first ?? ""
            let mainName = main.isEmpty ? "\(stem).\(Self.extensionFor(language))" : Self.fileName(main)
            let path = unique("code/\(stem)/\(mainName)")
            files[path] = Data((sources[main] ?? "").utf8)
            for name in names.dropFirst() {
                let extra = unique("code/\(stem)/\(Self.fileName(name))")
                files[extra] = Data((sources[name] ?? "").utf8)
            }
            entry.type = "code"
            entry.mode = language.rawValue
            entry.file = path
            entry.previewWidth = previewWidth
            entry.tokens = tokens.use(in: names.compactMap { sources[$0] }.joined(separator: "\n"))
            Self.origin(of: item.source, into: &entry)
            if let source = item.source {
                // A foreign card stays in the package. Its licence decides whether it is free to use.
                entry.free = License.isFree(source.license)
                if source.license?.isEmpty ?? true {
                    warnings.append("\(item.id.raw): license missing")
                } else if entry.free == false {
                    warnings.append("\(item.id.raw): license not free")
                }
            }

        case .image(let assetID, _, _):
            entry.type = "image"
            let source = item.source
            if Self.isOwn(source) {
                if let asset = document.assets[assetID], let bytes = try? asset.data() {
                    let path = "images/\(assetID).\(asset.fileExtension)"
                    files[path] = bytes
                    entry.file = path
                } else {
                    warnings.append("\(item.id.raw): image bytes are missing")
                }
            } else {
                Self.origin(of: source, into: &entry)
            }

        case .note(let text):
            entry.type = "note"
            entry.text = text
            entry.tokens = tokens.use(in: text)

        case .text(let text, let style):
            entry.type = "text"
            entry.text = text
            entry.mode = style
            entry.tokens = tokens.use(in: text)

        case .swatch(let hex, _):
            entry.type = "swatch"
            entry.color = hex
            entry.tokens = tokens.use(color: hex)

        case .link(let url, let note):
            entry.type = "link"
            entry.url = url.absoluteString
            entry.text = note

        case .shape(let kind, let style):
            entry.type = "shape"
            entry.mode = kind.rawValue
            entry.fill = style.fill
            entry.stroke = style.stroke

        case .frame, .group:
            return
        }
        entries.append(entry)
    }

    /// A path that no file has taken yet. A name that is taken is kept apart with a number, and the clash is reported.
    private mutating func unique(_ path: String) -> String {
        guard files[path] != nil else { return path }
        var number = 2
        while true {
            let (stem, ext) = Self.splitExtension(path)
            let candidate = ext.isEmpty ? "\(stem)-\(number)" : "\(stem)-\(number).\(ext)"
            if files[candidate] == nil {
                warnings.append("\(path): name taken, saved as \(candidate)")
                return candidate
            }
            number += 1
        }
    }

    /// The file names of a card with the entry file first: index.html, else the first HTML file, else the first name.
    static func orderedNames<S: Sequence>(_ names: S) -> [String] where S.Element == String {
        let sorted = names.sorted()
        let entry = sorted.first { $0 == "index.html" }
            ?? sorted.first { ["html", "htm"].contains(($0 as NSString).pathExtension.lowercased()) }
            ?? sorted.first
        guard let entry else { return [] }
        return [entry] + sorted.filter { $0 != entry }
    }

    static func splitExtension(_ path: String) -> (stem: String, ext: String) {
        let ns = path as NSString
        let ext = ns.pathExtension
        guard !ext.isEmpty else { return (path, "") }
        return (String(path.dropLast(ext.count + 1)), ext)
    }

    /// A name for a file or a folder in the package. Lower case. Letters of any script, digits, "-", "_" and "." survive;
    /// other characters become "-". A dot never starts the name, so the extension stays with the name.
    static func fileName(_ raw: String) -> String {
        var out = ""
        for character in raw.lowercased() {
            let keep = character.isLetter || character.isNumber || character == "-" || character == "_" || character == "."
            out.append(keep ? character : "-")
        }
        while out.hasPrefix(".") { out.removeFirst() }
        return out.isEmpty ? "item" : out
    }

    /// Own images go into the package: an item without a source, or one marked as own.
    /// Any other image is only a link with its license.
    static func isOwn(_ source: Source?) -> Bool {
        License.isOwn(source)
    }

    /// Copies the link, license and origin of a source. An item without a source keeps these fields empty.
    static func origin(of source: Source?, into entry: inout MockupManifest.Entry) {
        guard let source else { return }
        entry.url = source.url?.absoluteString
        entry.license = source.license
        entry.via = source.via.isEmpty ? nil : source.via
    }

    static func extensionFor(_ language: CodeLanguage) -> String {
        switch language {
        case .html, .tailwind: "html"
        case .css: "css"
        case .javascript: "js"
        case .react: "jsx"
        case .swiftui: "swift"
        case .compose: "kt"
        case .flutter: "dart"
        case .java: "java"
        case .other: "txt"
        }
    }

    /// Lower-case ASCII letters, digits, "-" and "_". Anything else becomes "-". Never empty.
    static func safeName(_ raw: String) -> String {
        var out = ""
        for character in raw.lowercased() {
            let plain = character.isASCII && (character.isLetter || character.isNumber)
            out.append(plain || character == "-" || character == "_" ? character : "-")
        }
        return out.isEmpty ? "item" : out
    }
}
