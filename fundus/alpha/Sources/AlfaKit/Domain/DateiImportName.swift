import Foundation

public enum DateiImportName {
    private static let verboten = CharacterSet(charactersIn: "/\\:\n\r\t")
        .union(.controlCharacters)

    public static func bereinige(_ input: String, fallback: String) -> String {
        var s = String(String.UnicodeScalarView(input.unicodeScalars.filter { !verboten.contains($0) }))
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }

        while s.hasPrefix(".") { s.removeFirst() }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? fallback : s
    }

    public static func basisUndEndung(_ name: String) -> (basis: String, endung: String) {
        guard let point = name.lastIndex(of: "."), point != name.startIndex else {
            return (name, "")
        }
        return (String(name[..<point]), String(name[point...]))
    }

    public static func mitOriginalEndung(basis: String, original: String) -> String {
        let endung = basisUndEndung(original).endung
        let roheBasis = bereinige(basis, fallback: basisUndEndung(original).basis)

        if endung.isEmpty || roheBasis.lowercased().hasSuffix(endung.lowercased()) {
            return bereinige(roheBasis, fallback: original)
        }
        return bereinige(roheBasis + endung, fallback: original)
    }
}
