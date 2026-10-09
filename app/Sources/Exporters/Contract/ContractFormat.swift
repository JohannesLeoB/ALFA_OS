import ALFAcolorCore
import CryptoKit
import Document
import Foundation
import Tokens
import UniformTypeIdentifiers

/// Errors of the contract export.
public enum ContractExportError: Error, Equatable, Sendable {
    /// The document has no token set named `vertrag`, so there is nothing to hand back.
    case noContractSet
}

/// The contract ZIP that goes back to the design side: `vertrag_<date>.zip` with MANIFEST.json,
/// `vertrag/tokens.json` and, when the document has one, `vertrag/tokens.dunkel.json`. Format: plan/AUSTAUSCH.md section 1.
/// The values are written in full precision, so that reading the ZIP gives the same token set.
public struct ContractFormat: ExchangeFormat {
    public let id = "contract"
    public let name = String(localized: "exchange.contract.name")
    public let contentTypes: [UTType] = [.zip]
    public let capabilities: ExchangeCapabilities = .write
    /// Time of the package. It goes into the manifest, the ZIP entries and the file name.
    public let created: Date

    public static let format = "setzkasten-vertrag/1"
    static let lightName = "vertrag"
    static let darkName = "vertrag-dunkel"

    public init(created: Date = .now) {
        self.created = created
    }

    public func write(_ document: ALFAcolorDocument, scope: ExchangeScope) throws -> ExchangeOutput {
        let archive = try Self.archive(document, created: created)
        return .file(name: Self.fileName(created), type: .zip, data: archive)
    }

    /// vertrag_<JJJJ-MM-TT_HHMM>.zip, in local time.
    public static func fileName(_ date: Date) -> String {
        "vertrag_\(stamp(date)).zip"
    }

    /// The archive bytes for a document. Ignores the scope: the contract is always the whole token set.
    public static func archive(_ document: ALFAcolorDocument, created: Date) throws -> Data {
        guard let light = document.tokenSets.first(where: { $0.name == lightName }) else {
            throw ContractExportError.noContractSet
        }
        var files: [(path: String, data: Data)] = [("vertrag/tokens.json", try dtcg(light))]
        if let dark = document.tokenSets.first(where: { $0.name == darkName }) {
            files.append(("vertrag/tokens.dunkel.json", try dtcg(dark)))
        }
        let fassung = stamp(created)
        let listed: [[String: String]] = files.map { file in
            ["pfad": file.path, "sha256": hex(SHA256.hash(data: file.data)), "fassung": fassung]
        }
        let manifest: [String: Any] = ["format": format, "von": "code", "datum": fassung, "dateien": listed]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])

        var zip = ZipWriter()
        try zip.add("MANIFEST.json", data: manifestData)
        for file in files {
            try zip.add(file.path, data: file.data)
        }
        return try zip.archive(modified: created)
    }

    // MARK: - Helpers

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: date)
    }

    static func hex(_ digest: SHA256Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    /// A DTCG 2025.10 tree of the set. Same shape as `TokenExport.dtcg`, but without rounding.
    /// JSONEncoder writes the shortest exact form of each number; JSONSerialization does not.
    static func dtcg(_ set: TokenSet) throws -> Data {
        var root: [String: JSONValue] = [:]
        for token in set.tokens {
            var leaf: [String: JSONValue] = ["$type": .string(token.value.dtcgType), "$value": value(token.value)]
            if let description = token.description { leaf["$description"] = .string(description) }
            insert(&root, path: token.path, leaf: leaf)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(JSONValue.object(root))
    }

    static func value(_ v: TokenValue) -> JSONValue {
        switch v {
        case .color(let c):
            return .object(["colorSpace": .string("srgb"), "components": .array([.double(c.r), .double(c.g), .double(c.b)]),
                            "alpha": .double(c.a), "hex": .string(String(c.hex.prefix(7)))])
        case .dimension(let x, let unit): return .object(["value": .double(x), "unit": .string(unit)])
        case .number(let x): return .double(x)
        case .duration(let ms): return .object(["value": .double(ms), "unit": .string("ms")])
        case .fontFamily(let f): return .array(f.map(JSONValue.string))
        case .fontWeight(let w): return .int(w)
        case .cubicBezier(let a, let b, let c, let d): return .array([.double(a), .double(b), .double(c), .double(d)])
        case .typography(let t):
            return .object(["fontFamily": .array(t.fontFamily.map(JSONValue.string)),
                            "fontSize": .object(["value": .double(t.fontSize), "unit": .string("px")]),
                            "fontWeight": .int(t.fontWeight),
                            "letterSpacing": .object(["value": .double(t.letterSpacing), "unit": .string("px")]),
                            "lineHeight": .double(t.lineHeight)])
        }
    }

    private static func insert(_ node: inout [String: JSONValue], path: [String], leaf: [String: JSONValue]) {
        guard let head = path.first else { return }
        if path.count == 1 {
            node[head] = .object(leaf)
            return
        }
        var child: [String: JSONValue] = [:]
        if case .object(let existing)? = node[head] { child = existing }
        insert(&child, path: Array(path.dropFirst()), leaf: leaf)
        node[head] = .object(child)
    }
}
