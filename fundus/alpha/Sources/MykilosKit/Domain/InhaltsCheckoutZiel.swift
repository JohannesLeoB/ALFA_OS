import Foundation

public struct InhaltsCheckoutZiel: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public let icon: String
    public let subtitle: String
    public let akzeptiert: Set<InhaltsArt>

    public let verfuegbar: Bool

    public init(id: String, name: String, icon: String, subtitle: String,
                akzeptiert: Set<InhaltsArt>, verfuegbar: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.subtitle = subtitle
        self.akzeptiert = akzeptiert
        self.verfuegbar = verfuegbar
    }

    public static let kontakteCSV = InhaltsCheckoutZiel(
        id: "kontakte-csv",
        name: "CSV / Excel",
        icon: "tablecells",
        subtitle: "Sichtbare Kontakte als Tabelle zum Weiterverarbeiten",
        akzeptiert: [.kontakte],
        verfuegbar: true)

    public static let kontakteListePDF = InhaltsCheckoutZiel(
        id: "kontakte-liste-pdf",
        name: "Kontaktliste als PDF",
        icon: "doc.text",
        subtitle: "Druckbare Liste im mykilOS-Stil",
        akzeptiert: [.kontakte],
        verfuegbar: true)

    public static let briefeDokumente = InhaltsCheckoutZiel(
        id: "briefe-dokumente",
        name: "Briefe & Dokumente",
        icon: "textformat",
        subtitle: "In-App-Dokument auf Dokumentenvorlage, Empfänger vorbefüllt",
        akzeptiert: [.kontakte, .textbausteine],
        verfuegbar: false)

    public static let aufgabenCSV = InhaltsCheckoutZiel(
        id: "aufgaben-csv",
        name: "Aufgabenliste (CSV)",
        icon: "checklist",
        subtitle: "Sichtbare Aufgaben als Tabelle",
        akzeptiert: [.aufgaben],
        verfuegbar: true)

    public func mitVerfuegbar(_ flag: Bool) -> InhaltsCheckoutZiel {
        InhaltsCheckoutZiel(id: id, name: name, icon: icon, subtitle: subtitle,
                            akzeptiert: akzeptiert, verfuegbar: flag)
    }

    public static let alle: [InhaltsCheckoutZiel] = [
        kontakteCSV, kontakteListePDF, briefeDokumente, aufgabenCSV
    ]

    public static func targetsFor(_ arten: Set<InhaltsArt>) -> [InhaltsCheckoutZiel] {
        guard arten.isEmpty == false else { return [] }
        return alle.filter { $0.akzeptiert.isDisjoint(with: arten) == false }
    }
}

public enum CSVWerk {
    public static func dokument(header: [String], rowItems: [[String]]) -> String {
        let alle = [header] + rowItems
        return "\u{FEFF}" + alle.map { rowItem in
            rowItem.map(escape).joined(separator: ";")
        }.joined(separator: "\r\n") + "\r\n"
    }

    private static func escape(_ feld: String) -> String {
        if feld.contains(";") || feld.contains("\"") || feld.contains("\n") {
            return "\"" + feld.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return feld
    }
}

public enum KontakteCSVExporter {
    public static func csv(fuer kontakte: [StudioContact]) -> String {
        CSVWerk.dokument(
            header: ["Name", "Organisation", "E-Mail", "Telefon", "Adresse"],
            rowItems: kontakte.map { k in
                [k.name, k.organisation ?? "", k.email ?? "", k.telefon ?? "", k.adresse ?? ""]
            })
    }
}

public struct AufgabenExportZeile: Sendable, Equatable {
    public let aufgabe: String
    public let status: String
    public let faelligAm: Date?
    public let zustaendig: String

    public init(aufgabe: String, status: String, faelligAm: Date?, zustaendig: String) {
        self.aufgabe = aufgabe
        self.status = status
        self.faelligAm = faelligAm
        self.zustaendig = zustaendig
    }
}

public enum AufgabenCSVExporter {
    private static let dateFormat: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd.MM.yyyy"
        fmt.locale = Locale(identifier: "de_DE")
        return fmt
    }()

    public static func csv(fuer aufgaben: [AufgabenExportZeile]) -> String {
        CSVWerk.dokument(
            header: ["Aufgabe", "Status", "Fällig am", "Zuständig"],
            rowItems: aufgaben.map { a in
                [a.aufgabe, a.status,
                 a.faelligAm.map { dateFormat.string(from: $0) } ?? "",
                 a.zustaendig]
            })
    }
}
