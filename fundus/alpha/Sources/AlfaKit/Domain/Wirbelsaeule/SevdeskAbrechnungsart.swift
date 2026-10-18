import Foundation

public struct SevdeskAbrechnungsart: Identifiable, Sendable, Equatable {
    public let name: String

    public let fusstext: String

    public let zahlungsplan: String

    public let textTemplateID: String

    public var id: String { name }

    public init(name: String, fusstext: String, zahlungsplan: String, textTemplateID: String) {
        self.name = name
        self.fusstext = fusstext
        self.zahlungsplan = zahlungsplan
        self.textTemplateID = textTemplateID
    }

    public static let alle: [SevdeskAbrechnungsart] = [
        SevdeskAbrechnungsart(
            name: "50/40/10",
            fusstext: "Zahlungsbedingungen: 50 % Anzahlung bei Auftragserteilung, 40 % vor Montagebeginn, 10 % nach Übergabe.",
            zahlungsplan: "50 % @ Start · 40 % @ Ende−21 T · 10 % @ Übergabe",
            textTemplateID: "9157043"),
        SevdeskAbrechnungsart(
            name: "50/50",
            fusstext: "Zahlungsbedingungen: 50 % Anzahlung bei Auftragserteilung, 50 % nach Lieferung.",
            zahlungsplan: "50 % @ Auftrag · 50 % @ Lieferung",
            textTemplateID: "9157042"),
        SevdeskAbrechnungsart(
            name: "100% Vorkasse",
            fusstext: "Zahlungsbedingung: 100 % Vorkasse bei Beauftragung.",
            zahlungsplan: "100 % @ Start (vor Lieferung)",
            textTemplateID: "9157044"),
        SevdeskAbrechnungsart(
            name: "100% nach Rechnung",
            fusstext: "Zahlungsbedingung: 100 % zahlbar nach Rechnungserhalt, 14 Tage netto.",
            zahlungsplan: "100 % @ Ende + 14 T",
            textTemplateID: "9157045"),
        SevdeskAbrechnungsart(
            name: "Stunden",
            fusstext: "Abrechnung: monatlich auf Stundenbasis, 150 € netto/h.",
            zahlungsplan: "monatlich über Laufzeit",
            textTemplateID: "9157046")
    ]

    public static func mit(name: String?) -> SevdeskAbrechnungsart? {
        guard let name else { return nil }
        return alle.first { $0.name == name }
    }
}
