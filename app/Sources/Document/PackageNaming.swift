import Foundation

/// Dateinamen im Paket. IDs und Namen sind frei; auf der Platte stehen nur ASCII-Buchstaben, Ziffern, "-" und "_".
/// Alles andere wird als %XX (UTF-8-Bytes, große Hex-Ziffern) geschrieben. Das ist umkehrbar und sicher:
/// kein "/", kein "..", keine Unicode-Normalisierungsfalle. Die echte ID steht immer auch in der JSON-Datei.
enum PackageNaming {
    static let maxLength = 200

    static func encode(_ id: String) throws -> String {
        guard !id.isEmpty else { throw PackageError.invalidIdentifier(id) }
        var out = ""
        for byte in id.utf8 {
            switch byte {
            case 48...57, 65...90, 97...122, 45, 95: out.unicodeScalars.append(Unicode.Scalar(byte))
            default: out += "%" + hex(byte >> 4) + hex(byte & 0xF)
            }
        }
        guard out.utf8.count <= maxLength else { throw PackageError.invalidIdentifier(id) }
        return out
    }

    /// Umkehrung. Zeichen ohne "%" bleiben, wie sie sind (von Hand angelegte Ordner).
    static func decode(_ name: String) -> String {
        let b = Array(name.utf8)
        var bytes: [UInt8] = []
        var i = 0
        while i < b.count {
            if b[i] == 37, i + 2 < b.count, let hi = value(b[i + 1]), let lo = value(b[i + 2]) {
                bytes.append(hi << 4 | lo); i += 3
            } else { bytes.append(b[i]); i += 1 }
        }
        return String(validating: bytes, as: UTF8.self) ?? name
    }

    /// Prüft eine Liste von IDs auf Doppelte und gibt ID -> Dateiname zurück. Als doppelt gilt, was in Swift gleich ist
    /// (auch é als ein Zeichen oder als e plus Akzent) oder auf der Platte denselben Namen ergäbe (Groß-/Kleinschreibung, APFS).
    static func requireDistinct(_ ids: [String], kind: String) throws -> [String: String] {
        var seen = Set<String>()
        var lowered = Set<String>()
        var names: [String: String] = [:]
        for id in ids {
            let name = try encode(id)
            guard seen.insert(id).inserted, lowered.insert(name.lowercased()).inserted else {
                throw PackageError.duplicateIdentifier(kind: kind, id: id)
            }
            names[id] = name
        }
        return names
    }

    private static func hex(_ n: UInt8) -> String { String(n, radix: 16, uppercase: true) }
    private static func value(_ c: UInt8) -> UInt8? {
        switch c {
        case 48...57: c - 48
        case 65...70: c - 55
        case 97...102: c - 87
        default: nil
        }
    }

    /// Pfade, die das Paket mitführt, müssen relativ und ohne Tricks sein.
    static func isSafe(path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255 }
    }
}
