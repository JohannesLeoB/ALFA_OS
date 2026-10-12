import Foundation

public enum MediathekBildPfad {
    public static let papersMarker = "mykilOS Papers"

    public static func relativerTeil(_ drivePfad: String) -> String? {
        let pfad = drivePfad.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
        guard pfad.isEmpty == false else { return nil }
        if let area = pfad.range(of: papersMarker + "/") {
            let rest = String(pfad[area.upperBound...])
            return rest.isEmpty ? nil : rest
        }

        return pfad.hasPrefix("/") ? nil : pfad
    }

    public static func lokaleURL(drivePfad: String, papersRoot: URL) -> URL? {
        guard let rel = relativerTeil(drivePfad) else { return nil }
        return papersRoot.appendingPathComponent(rel)
    }
}
