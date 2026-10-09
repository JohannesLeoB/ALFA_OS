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

        switch item.content {
        case .code(let language, let sources, let previewWidth):
            let names = sources.keys.sorted()
            let stem = Self.safeName(item.id.raw)
            let path = "code/\(stem).\(Self.extensionFor(language))"
            files[path] = Data((names.first.flatMap { sources[$0] } ?? "").utf8)
            for name in names.dropFirst() {
                files["code/\(stem)/\(Self.safeName(name))"] = Data((sources[name] ?? "").utf8)
            }
            entry.type = "code"
            entry.mode = language.rawValue
            entry.file = path
            entry.previewWidth = previewWidth
            entry.tokens = tokens.use(in: names.compactMap { sources[$0] }.joined(separator: "\n"))

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
                entry.url = source?.url?.absoluteString
                entry.license = source?.license
                entry.via = source?.via
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

    /// Own images go into the package: an item without a source, or one marked as own.
    /// Any other image is only a link with its license.
    static func isOwn(_ source: Source?) -> Bool {
        guard let source else { return true }
        return source.via.lowercased() == "eigen" || source.license?.lowercased() == "eigen"
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
