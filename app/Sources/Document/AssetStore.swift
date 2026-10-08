import Foundation
import CryptoKit

/// Die Binärdateien eines Dokuments (Bilder), einmal je Inhalt. Die ID ist der SHA-256 des Inhalts
/// in Kleinbuchstaben-Hex; dieselbe ID steht in `Content.image(assetID:)` und im Dateinamen `assets/<id>.<ext>`.
public struct AssetStore: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let fileExtension: String
        public let data: Data
    }

    public private(set) var entries: [String: Entry] = [:]
    public init() {}

    /// Legt Bytes ab und gibt die ID zurück. Dieselben Bytes ergeben dieselbe ID und liegen nur einmal da;
    /// die Endung des ersten Ablegens bleibt.
    @discardableResult
    public mutating func add(_ data: Data, fileExtension: String) -> String {
        let id = Self.hash(of: data)
        if entries[id] == nil { entries[id] = Entry(fileExtension: Self.cleanExtension(fileExtension), data: data) }
        return id
    }

    public subscript(id: String) -> Entry? { entries[id] }
    public var ids: [String] { entries.keys.sorted() }
    public var count: Int { entries.count }
    public mutating func remove(_ id: String) { entries[id] = nil }

    /// SHA-256 als 64 Zeichen Hex, klein.
    public static func hash(of data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var out = [UInt8](); out.reserveCapacity(64)
        for byte in SHA256.hash(data: data) { out.append(digits[Int(byte >> 4)]); out.append(digits[Int(byte & 0xF)]) }
        return String(decoding: out, as: UTF8.self)
    }

    /// Endung klein, ohne Punkt, nur a-z0-9, höchstens 16 Zeichen; sonst "bin".
    public static func cleanExtension(_ ext: String) -> String {
        let e = ext.lowercased().drop(while: { $0 == "." })
        return isValidExtension(String(e)) ? String(e) : "bin"
    }
    static func isValidExtension(_ e: String) -> Bool {
        !e.isEmpty && e.utf8.count <= 16 && e.utf8.allSatisfy { ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) }
    }
    static func isValidID(_ id: String) -> Bool {
        id.utf8.count == 64 && id.utf8.allSatisfy { ($0 >= 97 && $0 <= 102) || ($0 >= 48 && $0 <= 57) }
    }

    /// Für den Leser: Eintrag ohne Nachrechnen des Hashs übernehmen.
    mutating func insertLoaded(id: String, fileExtension: String, data: Data) {
        entries[id] = Entry(fileExtension: fileExtension, data: data)
    }
}
