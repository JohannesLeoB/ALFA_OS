import Foundation

public struct VWTitelblock: Sendable, Equatable {
    public var projektKunde: String

    public var raum: String

    public var strasse: String

    public var plz: String

    public var ort: String

    public var customerNumber: String?

    public var date: String

    public var massstab: String

    public var layout: String

    public var format: String

    public var zeichner: String

    public var firma: String
    public var firmaAdresse: String
    public var firmaMail: String
    public var firmaWeb: String
    public var firmaTel: String

    public init(
        projektKunde: String,
        raum: String = "Küche",
        strasse: String,
        plz: String,
        ort: String,
        customerNumber: String? = nil,
        date: String,
        massstab: String = "1:20",
        layout: String = "A0 Layout",
        format: String = "DIN A0",
        zeichner: String = "GEZ",
        firma: String = "MYKILOS GmbH",
        firmaAdresse: String = CompanySetup.valueOrEmpty("company.address"),
        firmaMail: String = CompanySetup.valueOrEmpty("company.mail.projects"),
        firmaWeb: String = CompanySetup.valueOrEmpty("company.web"),
        firmaTel: String = CompanySetup.valueOrEmpty("company.phone")
    ) {
        self.projektKunde = projektKunde
        self.raum = raum
        self.strasse = strasse
        self.plz = plz
        self.ort = ort
        self.customerNumber = customerNumber
        self.date = date
        self.massstab = massstab
        self.layout = layout
        self.format = format
        self.zeichner = zeichner
        self.firma = firma
        self.firmaAdresse = firmaAdresse
        self.firmaMail = firmaMail
        self.firmaWeb = firmaWeb
        self.firmaTel = firmaTel
    }

    public static let massHinweis =
        "Alle Maße sind vor Ort zu prüfen bzw. am Bau zu nehmen. Unstimmigkeiten sind der "
        + "Bauleitung unverzüglich mitzuteilen. Höhenangaben sind auf OKFF bezogen, sofern nicht anders vermerkt."

    public static let massEinheit = "Alle Maßangaben in Millimetern. Alle Maße sind am Bau zu prüfen."

    public static let eigentumshinweis =
        "Diese Zeichnung ist Eigentum der MYKILOS GmbH. Vervielfältigung und Weiterverwendung "
        + "sind nicht gestattet. Änderungen nur in Absprache mit der MYKILOS GmbH."

    public var objektadresse: String {
        let plzOrt = [plz, ort].filter { $0.isEmpty == false }.joined(separator: " ")
        return [strasse, plzOrt].filter { $0.isEmpty == false }.joined(separator: ", ")
    }

    public func render() -> String {
        var lines: [String] = []
        lines.append("── PLANKOPF · \(firma) ──")
        lines.append("Projekt / Kunde:  \(projektKunde)")
        lines.append("Raum:             \(raum)")
        lines.append("Objektadresse:    \(objektadresse)")
        lines.append("Kundennummer:     \(customerNumber.flatMap { $0.isEmpty ? nil : $0 } ?? "—")")
        lines.append("Datum:            \(date)")
        lines.append("Maßstab:          \(massstab)")
        lines.append("Layout / Format:  \(layout) · \(format)")
        lines.append("Gezeichnet:       \(zeichner)")
        lines.append("")
        lines.append(Self.massEinheit)
        lines.append("")
        lines.append(Self.eigentumshinweis)
        lines.append("")
        lines.append("\(firma) · \(firmaAdresse) · \(firmaTel)")
        lines.append("\(firmaMail) · \(firmaWeb)")
        return lines.joined(separator: "\n")
    }
}
