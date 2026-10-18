import Foundation

public enum GeraeteListeExporter {
    public static let delimiter = ";"

    public struct Header: Sendable, Equatable {
        public var label: String?
        public var projekt: String?
        public var date: Date

        public init(label: String? = nil, projekt: String? = nil, date: Date = Date()) {
            self.label = label
            self.projekt = projekt
            self.date = date
        }
    }

    private static let dateFormat: DateFormatter = {
        let fmt = DateFormatter(); fmt.dateFormat = "dd.MM.yyyy"; fmt.locale = Locale(identifier: "de_DE"); return fmt
    }()

    public static func csv(positionen: [WarenkorbItem], header: Header = Header()) -> String {
        var rowItems: [String] = []

        if let label = header.label, label.isEmpty == false {
            rowItems.append(feld("Geräteliste") + delimiter + feld(label))
        }
        if let projekt = header.projekt, projekt.isEmpty == false {
            rowItems.append(feld("Projekt") + delimiter + feld(projekt))
        }
        rowItems.append(feld("Datum") + delimiter + feld(dateFormat.string(from: header.date)))
        rowItems.append(feld("Positionen") + delimiter + feld(String(positionen.count)))
        rowItems.append("")

        let columns = ["Pos.", "Artikelnummer", "Bezeichnung", "Lieferant", "Kategorie", "Menge"]
        rowItems.append(columns.map(feld).joined(separator: delimiter))

        for (index, position) in positionen.enumerated() {
            let felder = [
                String(index + 1),
                position.articleNumber,
                position.label,
                position.attribute["lieferant"] ?? "",
                position.attribute["kategorie"] ?? "",
                String(position.quantity)
            ]
            rowItems.append(felder.map(feld).joined(separator: delimiter))
        }

        return "\u{FEFF}" + rowItems.joined(separator: "\r\n")
    }

    public static func feld(_ roh: String) -> String {
        let mussQuoten = roh.contains(delimiter) || roh.contains("\"")
            || roh.contains("\n") || roh.contains("\r")
        guard mussQuoten else { return roh }
        return "\"" + roh.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
