import Foundation

public struct SevdeskManuellNachtrag: Sendable, Equatable {
    public struct Punkt: Sendable, Equatable, Identifiable {
        public let id: String

        public let feld: String

        public let value: String

        public let ground: String

        public init(id: String, feld: String, value: String, ground: String) {
            self.id = id; self.feld = feld; self.value = value; self.ground = ground
        }
    }

    public let points: [Punkt]

    public init(points: [Punkt]) { self.points = points }

    public var isEmpty: Bool { points.isEmpty }

    public var alsText: String {
        guard isEmpty == false else { return "Nichts nachzutragen — alles per API übertragen." }
        let rowItems = points.map { "• \($0.feld): \($0.value)  (\($0.ground))" }
        return (["In sevDesk noch von Hand ergänzen:"] + rowItems).joined(separator: "\n")
    }
}

public enum SevdeskManuellNachtragBuilder {
    private static let grundKeinOrderFeld =
        "sevDesk hat dieses Feld nur an Rechnungen, nicht am Angebot"
    private static let grundNurUI =
        "die API kann keinen Gesamtrabatt anlegen — in sevDesk nur über „Gesamtrabatt hinzufügen“"
    private static let grundReferenzBelegt =
        "„Referenz / Bestellnummer“ trägt bereits die Projektnummer"

    private static let grundZahlungUndokumentiert =
        "„paymentTerms“ am Angebot ist undokumentiert — wird nicht geraten"
    private static let grundLandNichtAufloesbar =
        "die Länder-IDs (StaticCountry) haben keinen dokumentierten Endpoint — der Beleg trägt das Standard-Land des Mandanten"

    public static func erstelle(
        gesamtrabattProzent: Decimal? = nil,
        montagekosten: Decimal? = nil,
        projektbeginn: String? = nil,
        projektende: String? = nil,
        lieferant: String? = nil,
        fremdReferenz: String? = nil,
        zahlungsbedingung: String? = nil,
        landAbweichend: String? = nil
    ) -> SevdeskManuellNachtrag {
        var points: [SevdeskManuellNachtrag.Punkt] = []

        if let rabatt = gesamtrabattProzent, rabatt != 0 {
            points.append(.init(id: "gesamtrabatt", feld: "Gesamtrabatt",
                                value: prozent(rabatt), ground: grundNurUI))
        }
        if let montage = montagekosten, montage != 0 {
            points.append(.init(id: "montagekosten", feld: "Montagekosten",
                                value: euro(montage), ground: grundKeinOrderFeld))
        }
        if let beginn = bereinigt(projektbeginn) {
            points.append(.init(id: "projektbeginn", feld: "Projektbeginn",
                                value: beginn, ground: grundKeinOrderFeld))
        }
        if let ende = bereinigt(projektende) {
            points.append(.init(id: "projektende", feld: "Projektende",
                                value: ende, ground: grundKeinOrderFeld))
        }
        if let lieferant = bereinigt(lieferant) {
            points.append(.init(id: "lieferant", feld: "Lieferant",
                                value: lieferant, ground: grundKeinOrderFeld))
        }

        if let fremd = bereinigt(fremdReferenz) {
            points.append(.init(id: "fremdReferenz", feld: "Fremd-Referenznummer",
                                value: fremd, ground: grundReferenzBelegt))
        }
        if let zahlung = bereinigt(zahlungsbedingung) {
            points.append(.init(id: "zahlungsbedingung", feld: "Zahlungsbedingung",
                                value: zahlung, ground: grundZahlungUndokumentiert))
        }
        if let land = bereinigt(landAbweichend) {
            points.append(.init(id: "land", feld: "Land der Angebotsadresse",
                                value: land, ground: grundLandNichtAufloesbar))
        }
        return SevdeskManuellNachtrag(points: points)
    }

    private static func bereinigt(_ text: String?) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), t.isEmpty == false else { return nil }
        return t
    }

    static func prozent(_ value: Decimal) -> String {
        zahl(value) + " %"
    }

    static func euro(_ value: Decimal) -> String {
        zahl(value) + " €"
    }

    private static func zahl(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
