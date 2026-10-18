import Foundation

public enum GoogleDriveBildlink {
    public static func fileID(aus roh: String) -> String? {
        guard roh.contains("drive.google.com") || roh.contains("docs.google.com")
              || roh.contains("googleusercontent.com") else { return nil }

        if let area = roh.range(of: "/d/") {
            if let id = plausibleID(roh[area.upperBound...]) { return id }
        }

        if let area = roh.range(of: "id=") {
            if let id = plausibleID(roh[area.upperBound...]) { return id }
        }
        return nil
    }

    public static func direkteURL(fuerID id: String) -> URL? {
        URL(string: "https://lh3.googleusercontent.com/d/\(id)=w1000")
    }

    public static func direkteURL(ausLink roh: String) -> URL? {
        guard let id = fileID(aus: roh) else { return nil }
        return direkteURL(fuerID: id)
    }

    private static func plausibleID(_ rest: Substring) -> String? {
        let id = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return id.count >= 16 ? String(id) : nil
    }
}
