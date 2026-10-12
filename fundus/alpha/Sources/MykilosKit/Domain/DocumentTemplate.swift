import Foundation

public enum DocumentTemplateKategorie: String, CaseIterable, Codable, Sendable, Identifiable {
    case anschreiben
    case brief
    case aktenvermerk
    case bestaetigung

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .anschreiben:  return "Anschreiben"
        case .brief:        return "Brief"
        case .aktenvermerk: return "Aktenvermerk"
        case .bestaetigung: return "Bestätigung"
        }
    }
}

public struct DocumentTemplate: Identifiable, Sendable, Equatable, Codable {
    enum CodingKeys: String, CodingKey { case id, title = "titel", kategorie, beschreibung, htmlVorlage }

    public let id: String
    public let title: String
    public let kategorie: DocumentTemplateKategorie
    public let beschreibung: String

    public let htmlVorlage: String

    public init(
        id: String,
        title: String,
        kategorie: DocumentTemplateKategorie,
        beschreibung: String,
        htmlVorlage: String
    ) {
        self.id = id
        self.title = title
        self.kategorie = kategorie
        self.beschreibung = beschreibung
        self.htmlVorlage = htmlVorlage
    }

    public var platzhalter: [String] {
        DocumentTemplatePlatzhalter.extrahiere(aus: htmlVorlage)
    }
}

public enum DocumentTemplatePlatzhalter {
    static let patterns = "\\{\\{\\s*([A-Za-z0-9_]+)\\s*\\}\\}"

    public static func extrahiere(aus html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: patterns) else { return [] }
        let area = NSRange(html.startIndex..<html.endIndex, in: html)
        var gesehen = Set<String>()
        var namen: [String] = []
        for match in regex.matches(in: html, range: area) {
            guard match.numberOfRanges >= 2,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let name = String(html[r])
            if gesehen.insert(name).inserted { namen.append(name) }
        }
        return namen
    }

    public static func ersetze(_ name: String, durch ersatz: String, in html: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = "\\{\\{\\s*\(escaped)\\s*\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let area = NSRange(html.startIndex..<html.endIndex, in: html)
        let ersatzEscaped = NSRegularExpression.escapedTemplate(for: ersatz)
        return regex.stringByReplacingMatches(in: html, range: area, withTemplate: ersatzEscaped)
    }
}

public enum DocumentTemplateRenderer {
    public struct Result: Sendable, Equatable {
        public let html: String

        public let fehlendePlatzhalter: [String]

        public init(html: String, fehlendePlatzhalter: [String]) {
            self.html = html
            self.fehlendePlatzhalter = fehlendePlatzhalter
        }
    }

    public static func fuelle(_ template: DocumentTemplate, mit values: [String: String]) -> Result {
        let deklariert = template.platzhalter
        var html = template.htmlVorlage
        var fehlend: [String] = []
        for name in deklariert {
            let roh = values[name]
            if roh == nil { fehlend.append(name) }
            let ersatz = htmlEscape(roh ?? "")
            html = DocumentTemplatePlatzhalter.ersetze(name, durch: ersatz, in: html)
        }
        return Result(html: html, fehlendePlatzhalter: fehlend)
    }

    static func htmlEscape(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "&", with: "&amp;")
        s = s.replacingOccurrences(of: "<", with: "&lt;")
        s = s.replacingOccurrences(of: ">", with: "&gt;")
        s = s.replacingOccurrences(of: "\"", with: "&quot;")
        s = s.replacingOccurrences(of: "'", with: "&#39;")
        return s
    }
}
