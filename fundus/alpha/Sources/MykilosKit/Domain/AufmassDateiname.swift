import Foundation

public enum AufmassDateiname {
    public static func datumTeil(_ date: Date, zeitzone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zeitzone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func datumZeitTeil(_ date: Date, zeitzone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zeitzone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d-%02d-%02d_%02d%02d",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }

    public static func fileName(projektLabel: String, label: String,
                                 datumTeil: String, endung: String) -> String {
        var teile: [String] = []
        let p = slug(projektLabel)
        if p.isEmpty == false { teile.append(p) }
        teile.append("Aufmaß")
        let b = slug(label)
        if b.isEmpty == false
            && b.caseInsensitiveCompare("Aufmaß") != .orderedSame
            && b.caseInsensitiveCompare("Neues-Aufmaß") != .orderedSame {
            teile.append(b)
        }
        let d = slug(datumTeil)
        if d.isEmpty == false { teile.append(d) }
        let basis = teile.joined(separator: "_")
        return endung.isEmpty ? basis : basis + "." + endung
    }

    public static func fileName(projektLabel: String, label: String,
                                 date: Date, endung: String) -> String {
        fileName(projektLabel: projektLabel, label: label,
                  datumTeil: datumTeil(date), endung: endung)
    }

    static func slug(_ s: String) -> String {
        let verboten = CharacterSet(charactersIn: "/\\:.").union(.controlCharacters)
        let ohneVerboten = String(String.UnicodeScalarView(s.unicodeScalars.filter { verboten.contains($0) == false }))
        let mitBindestrich = ohneVerboten
            .components(separatedBy: .whitespaces)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")
        var out = mitBindestrich
        while out.contains("--") { out = out.replacingOccurrences(of: "--", with: "-") }
        while out.contains("__") { out = out.replacingOccurrences(of: "__", with: "_") }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
    }
}
