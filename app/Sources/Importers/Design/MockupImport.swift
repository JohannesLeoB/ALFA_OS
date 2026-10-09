import ALFAcolorCore
import Foundation

/// A mockup package read from a ZIP, before it is placed on the board (see plan/AUSTAUSCH.md section 2).
/// The package format is `alfacolor-mockup/1`. Unknown fields are ignored; unknown types and missing files are warnings.
public struct MockupDelivery: Equatable, Sendable {
    public struct Frame: Equatable, Sendable {
        public let id: String
        public let title: String
        public let width: Double
        public let height: Double
    }

    public struct Piece: Equatable, Sendable {
        public enum Content: Equatable, Sendable {
            case code(language: String, files: [String: String], previewWidth: Double?)
            case image(bytes: Data, fileExtension: String)
            case note(String)
            case text(String, style: String)
            case swatch(hex: String)
            case link(URL, note: String?)
        }

        public let id: String
        public let title: String
        /// The id of the frame the piece lies on. Nil on the free sheet.
        public let frame: String?
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
        public let layer: String?
        public let content: Content
        public let source: Source
    }

    public let title: String
    public let frames: [Frame]
    public let pieces: [Piece]
    public let warnings: [String]
}

/// Why a mockup package cannot be read.
public enum MockupImportError: Error, Equatable, Sendable {
    case noManifest
    case badFormat
    case badManifest(String)
}

public enum MockupImport {
    public static let format = "alfacolor-mockup/1"
    /// Where the source of a piece without its own origin points.
    public static let defaultVia = "claude"
    /// Limits for the files of code cards, in bytes. One file over `codeBytesPerFile` is not read.
    /// The other files of one card stay within `siblingBytesPerCard`, all cards together within `siblingBytesPerPackage`.
    static let codeBytesPerFile = 4 << 20
    static let siblingBytesPerCard = 16 << 20
    static let siblingBytesPerPackage = 64 << 20

    /// Reads the package. `now` is the time of the import, used for the source of each piece.
    public static func read(_ contents: ZipContents, now: Date = .now) throws -> MockupDelivery {
        let files = Dictionary(contents.files.map { ($0.path, $0.data) }, uniquingKeysWith: { first, _ in first })
        guard let manifestData = files["manifest.json"] else { throw MockupImportError.noManifest }
        guard let root = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any] else {
            throw MockupImportError.badManifest("manifest.json is not a JSON object")
        }
        guard root["format"] as? String == format else { throw MockupImportError.badFormat }

        var warnings = contents.problems.map { "\($0.path): \($0.reason)" }
        let title = root["title"] as? String ?? ""
        let frames = try (root["frames"] as? [[String: Any]] ?? []).map { try frame($0) }
        let rawItems = root["items"] as? [[String: Any]] ?? []

        var pieces: [MockupDelivery.Piece] = []
        var budget = SiblingBudget()
        for raw in rawItems {
            let id = raw["id"] as? String ?? "(no id)"
            guard let type = raw["type"] as? String else {
                warnings.append("\(id): no type, skipped")
                continue
            }
            guard let piece = try piece(raw, id: id, type: type, files: files, now: now, budget: &budget, warnings: &warnings) else { continue }
            pieces.append(piece)
        }
        if budget.skipped > 0 {
            warnings.append("\(budget.skipped) code files are not read: over the size limits")
        }
        let knownFrames = Set(frames.map(\.id))
        for piece in pieces {
            if let frame = piece.frame, !knownFrames.contains(frame) {
                warnings.append("\(piece.id): frame \(frame) is not in the package, placed on the sheet")
            }
        }
        return MockupDelivery(title: title, frames: frames, pieces: pieces, warnings: warnings)
    }

    // MARK: - Frames and pieces

    private static func frame(_ raw: [String: Any]) throws -> MockupDelivery.Frame {
        guard let id = raw["id"] as? String, !id.isEmpty else { throw MockupImportError.badManifest("a frame has no id") }
        let width = try number(raw["width"], "frame \(id) width")
        let height = try number(raw["height"], "frame \(id) height")
        guard width > 0, height > 0 else { throw MockupImportError.badManifest("frame \(id) has no size") }
        return MockupDelivery.Frame(id: id, title: raw["title"] as? String ?? id, width: width, height: height)
    }

    private static func piece(_ raw: [String: Any], id: String, type: String, files: [String: Data], now: Date,
                              budget: inout SiblingBudget, warnings: inout [String]) throws -> MockupDelivery.Piece? {
        let content: MockupDelivery.Piece.Content
        switch type {
        case "code":
            guard let path = raw["file"] as? String, let main = files[path] else {
                warnings.append("\(id): code file is missing, skipped")
                return nil
            }
            guard main.count <= codeBytesPerFile else {
                warnings.append("\(id): code file is over the size limit, skipped")
                return nil
            }
            let language = raw["mode"] as? String ?? "other"
            content = .code(language: language, files: siblings(of: path, in: files, main: main, budget: &budget),
                            previewWidth: raw["previewWidth"] as? Double)
        case "image":
            guard let path = raw["file"] as? String, let bytes = files[path] else {
                warnings.append("\(id): image file is missing, skipped")
                return nil
            }
            content = .image(bytes: bytes, fileExtension: (path as NSString).pathExtension)
        case "note":
            content = .note(raw["text"] as? String ?? "")
        case "text":
            content = .text(raw["text"] as? String ?? "", style: raw["mode"] as? String ?? "")
        case "swatch":
            guard let hex = raw["color"] as? String, isHexColor(hex) else {
                warnings.append("\(id): colour is not a hex value, skipped")
                return nil
            }
            content = .swatch(hex: hex)
        case "link":
            guard let text = raw["url"] as? String, let url = URL(string: text), ["http", "https"].contains(url.scheme ?? "") else {
                warnings.append("\(id): link is not http or https, skipped")
                return nil
            }
            content = .link(url, note: raw["text"] as? String)
        default:
            warnings.append("\(id): type \(type) is not read, skipped")
            return nil
        }
        let via = raw["via"] as? String
        let source = Source(url: (raw["url"] as? String).flatMap(URL.init(string:)),
                            license: raw["license"] as? String,
                            via: via.flatMap { $0.isEmpty ? nil : $0 } ?? defaultVia,
                            importedAt: now)
        return MockupDelivery.Piece(
            id: id, title: raw["title"] as? String ?? id, frame: raw["frame"] as? String,
            x: try number(raw["x"], "\(id) x"), y: try number(raw["y"], "\(id) y"),
            width: try number(raw["width"], "\(id) width"), height: try number(raw["height"], "\(id) height"),
            layer: raw["layer"] as? String, content: content, source: source)
    }

    /// The bytes of other files that the code cards of a package may still carry, and how many files were left out.
    private struct SiblingBudget {
        var packageLeft = MockupImport.siblingBytesPerPackage
        var skipped = 0
    }

    /// The other files of a card: they sit in the same folder as the entry file. Their names are the keys.
    /// Files that do not fit the limits are left out and counted in the budget, in name order.
    private static func siblings(of path: String, in files: [String: Data], main: Data, budget: inout SiblingBudget) -> [String: String] {
        let folder = (path as NSString).deletingLastPathComponent + "/"
        var result: [String: String] = [:]
        result[(path as NSString).lastPathComponent] = String(decoding: main, as: UTF8.self)
        var cardLeft = siblingBytesPerCard
        for other in files.keys.sorted() where other.hasPrefix(folder) && other != path {
            let name = String(other.dropFirst(folder.count))
            guard !name.contains("/"), let bytes = files[other] else { continue }
            guard bytes.count <= codeBytesPerFile, bytes.count <= cardLeft, bytes.count <= budget.packageLeft else {
                budget.skipped += 1
                continue
            }
            cardLeft -= bytes.count
            budget.packageLeft -= bytes.count
            result[name] = String(decoding: bytes, as: UTF8.self)
        }
        return result
    }

    private static func number(_ raw: Any?, _ what: String) throws -> Double {
        guard let value = raw as? Double, value.isFinite else {
            if let whole = raw as? Int { return Double(whole) }
            throw MockupImportError.badManifest("\(what) is not a number")
        }
        return value
    }

    private static func isHexColor(_ text: String) -> Bool {
        text.count == 7 && text.hasPrefix("#") && text.dropFirst().allSatisfy { $0.isHexDigit }
    }
}
