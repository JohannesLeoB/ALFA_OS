import Foundation

public struct CheckoutZiel: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String

    public let icon: String

    public let color: String
    public let subtitle: String

    public let verfuegbar: Bool
    public let neu: Bool

    public init(id: String, name: String, icon: String, color: String,
                subtitle: String, verfuegbar: Bool, neu: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.verfuegbar = verfuegbar
        self.neu = neu
    }
}

public extension CheckoutZiel {
    static let alle: [CheckoutZiel] = [
        CheckoutZiel(id: "sevdesk", name: "sevDesk-Angebot",
                     icon: "paperplane", color: "cash",
                     subtitle: "Angebotsentwurf — sevDesk holt ab, du bestätigst",
                     verfuegbar: true),
        CheckoutZiel(id: "kostenschaetzung", name: "Kostenschätzung ins Projekt",
                     icon: "function", color: "tasks",
                     subtitle: "Projekt wählen → PDF-Schätzung landet im Angebote-Tab des Projekts",
                     verfuegbar: true, neu: true),
        CheckoutZiel(id: "paper", name: "Paper — In-App-Dokument",
                     icon: "doc.richtext", color: "personal",
                     subtitle: "druckbares PDF im mykilOS-Stil",
                     verfuegbar: true),
        CheckoutZiel(id: "csv", name: "CSV / Excel",
                     icon: "tablecells", color: "people",
                     subtitle: "Tabelle zum Weiterverarbeiten",
                     verfuegbar: true),
        CheckoutZiel(id: "geraeteliste", name: "Geräteliste für den Tischler",
                     icon: "checklist", color: "drive",
                     subtitle: "Auswahl der Einbaugeräte — keine Preise",
                     verfuegbar: true, neu: true),
        CheckoutZiel(id: "bemusterung-entwurf", name: "Als Muster-Entwurf ins Projekt",
                     icon: "swatchpalette", color: "people",
                     subtitle: "Projekt wählen → Materialien + Geräte landen als Bemusterungs-Entwurf",
                     verfuegbar: true, neu: true),
        CheckoutZiel(id: "bestellung", name: "Bestellung ins Projekt",
                     icon: "shippingbox", color: "cash",
                     subtitle: "Projekt + Lieferant wählen → Positionen landen im Bestellungen-Tab",
                     verfuegbar: true, neu: true),
        CheckoutZiel(id: "vwplankopf", name: "Vectorworks-Plankopf",
                     icon: "ruler", color: "drive",
                     subtitle: "Projekt wählen → Titelblock-Felder als Text-Entwurf",
                     verfuegbar: true),
        CheckoutZiel(id: "moodboard", name: "Moodboard",
                     icon: "photo.on.rectangle", color: "people",
                     subtitle: "Bild-Collage (PNG)",
                     verfuegbar: false),
        CheckoutZiel(id: "zip", name: "ZIP-Download",
                     icon: "archivebox", color: "muted",
                     subtitle: "Warenkorb als Archiv (PDF + CSV)",
                     verfuegbar: true)
    ]
}
