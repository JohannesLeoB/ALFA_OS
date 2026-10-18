import Foundation

public struct AblaufSchritt: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let erklaerung: String

    public init(id: Int, title: String, erklaerung: String) {
        self.id = id
        self.title = title
        self.erklaerung = erklaerung
    }
}

public enum AblaufAbschluss: String, Codable, Equatable, Sendable {
    case fragebogenOeffnen
    case modulKataloge
    case modulProjekte
    case modulHeute
}

public struct GefuehrterAblauf: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let schritte: [AblaufSchritt]
    public let abschlussTitel: String
    public let abschluss: AblaufAbschluss

    public init(id: String, title: String, subtitle: String, symbol: String,
                schritte: [AblaufSchritt], abschlussTitel: String, abschluss: AblaufAbschluss) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.schritte = schritte
        self.abschlussTitel = abschlussTitel
        self.abschluss = abschluss
    }
}

public enum GefuehrteAblaeufe {
    public static let neuesProjekt = GefuehrterAblauf(
        id: "neues-projekt",
        title: "Neues Projekt anlegen",
        subtitle: "In vier Schritten vom Auftraggeber zum angelegten Projekt.",
        symbol: "plus.rectangle.on.folder",
        schritte: [
            AblaufSchritt(
                id: 1, title: "Auftraggeber",
                erklaerung: "Wer ist der Kunde — Person oder Firma? Ein bestehender Kunde wird über "
                    + "Kundennummer/Name zugeordnet, ein neuer bekommt eine eigene Kundennummer. Der "
                    + "Kundenname ist nie die Identität (Dedup läuft über Kundennummer/Mail/Telefon)."),
            AblaufSchritt(
                id: 2, title: "Projekt-Eckdaten",
                erklaerung: "Projektname und die Fragebogen-Antworten (Räume, Stil, Rahmen). Der "
                    + "Fragebogen ist der einzige Geburtskanal — dieselben Antworten speisen später "
                    + "PDF, Airtable-Rohdaten und die Antworten-Tabelle."),
            AblaufSchritt(
                id: 3, title: "Stufe wählen",
                erklaerung: "„Nur als Lead“ legt einen Rumpf-Ordner unter PROJEKTE/_LEADS an (erscheint "
                    + "als Lead in der Galerie). „Projekt mit Ordner“ vergibt die Projektnummer und legt "
                    + "den vollen Drive-Unterbau an."),
            AblaufSchritt(
                id: 4, title: "Bestätigen",
                erklaerung: "ALPHA vergibt die Projektnummer (Geburtsjahr, unveränderlich, atomar aus "
                    + "dem Register), legt Drive-Ordner + Airtable-Eintrag an und macht das Projekt in "
                    + "der Galerie sichtbar. Dublettenschutz läuft davor — nie doppelt angelegt.")
        ],
        abschlussTitel: "Fragebogen öffnen",
        abschluss: .fragebogenOeffnen)

    public static let sampling = GefuehrterAblauf(
        id: "bemusterung",
        title: "Bemusterung",
        subtitle: "Muster wählen, Bild prüfen, dem Projekt zuordnen.",
        symbol: "swatchpalette",
        schritte: [
            AblaufSchritt(
                id: 1, title: "Projekt",
                erklaerung: "Für welches Projekt bemusterst du? Die Bemusterung ist projektgebunden — "
                    + "sie landet in der Musterliste bzw. den Papers dieses Projekts."),
            AblaufSchritt(
                id: 2, title: "Muster suchen",
                erklaerung: "In Katalog UND Mediathek suchen (Name, Hersteller, Kategorie, EAN). Die "
                    + "Mediathek liefert die freigestellten Hersteller-Produktbilder — mit Bild-Vorschau "
                    + "vor der Auswahl, nichts blind."),
            AblaufSchritt(
                id: 3, title: "Zuordnen & ablegen",
                erklaerung: "Gewählte Muster kommen in die Musterliste des Projekts (Papers). Von dort "
                    + "wandern sie in Moodboard, Angebot oder Werkplanung weiter.")
        ],
        abschlussTitel: "Kataloge öffnen",
        abschluss: .modulKataloge)

    public static let angebotCheckout = GefuehrterAblauf(
        id: "angebot-checkout",
        title: "Angebot / Checkout",
        subtitle: "Warenkorb prüfen, Kunde, Konditionen, ablegen.",
        symbol: "cart",
        schritte: [
            AblaufSchritt(
                id: 1, title: "Warenkorb prüfen",
                erklaerung: "Positionen, Mengen und Rabatte durchgehen. Der Warenkorb ist die Basis "
                    + "des Angebots — hier stimmt, was der Kunde bekommt."),
            AblaufSchritt(
                id: 2, title: "Kunde & Adresse",
                erklaerung: "Empfänger, Lieferadresse und Kostenstelle (= Projektnummer). Ein "
                    + "bestehender Kunde wird zugeordnet, kein Neuanlegen auf Verdacht."),
            AblaufSchritt(
                id: 3, title: "Konditionen",
                erklaerung: "Zahlungsart, Termine, Montagekosten und Fußtext. Das sind die "
                    + "kaufmännischen Bedingungen des Angebots."),
            AblaufSchritt(
                id: 4, title: "Ablegen",
                erklaerung: "Vorschau prüfen, dann in die sevDesk-Postbox ablegen. ALPHA stellt NIE "
                    + "selbst einen verbuchungspflichtigen Beleg aus — sevDesk bleibt der Chef davon.")
        ],
        abschlussTitel: "Kataloge öffnen",
        abschluss: .modulKataloge)

    public static let aufmass = GefuehrterAblauf(
        id: "aufmass",
        title: "Aufmaß",
        subtitle: "Foto laden, kalibrieren, Maße setzen, exportieren.",
        symbol: "ruler",
        schritte: [
            AblaufSchritt(
                id: 1, title: "Foto/Plan laden",
                erklaerung: "Ein Baustellenfoto oder einen Grundriss laden. Das Bild ist die "
                    + "Vermessungs-Grundlage — je klarer die Kanten, desto besser das Auto-Maß."),
            AblaufSchritt(
                id: 2, title: "Kalibrieren",
                erklaerung: "EINE bekannte Referenzstrecke ziehen und ihren echten Meter-Wert eingeben. "
                    + "Erst danach kennt ALPHA den Maßstab — vorher wird KEINE Zahl erfunden."),
            AblaufSchritt(
                id: 3, title: "Maße setzen",
                erklaerung: "Von Hand messen ODER „Auto-Maß\": erkennt die Bildkanten und setzt alle "
                    + "achsparallelen Maße automatisch (Breiten/Höhen), gedeckelt und entdoppelt."),
            AblaufSchritt(
                id: 4, title: "Exportieren",
                erklaerung: "Als maßgenaues A3-CI-Blatt exportieren oder ans Projekt hängen. Das "
                    + "Aufmaß-Werkzeug liegt als Widget auf „Heute\".")
        ],
        abschlussTitel: "Heute öffnen (Aufmaß-Widget)",
        abschluss: .modulHeute)

    public static let projektArchivieren = GefuehrterAblauf(
        id: "projekt-archivieren",
        title: "Projekt archivieren",
        subtitle: "Projekt wählen, bestätigen, ins Archiv — rückholbar.",
        symbol: "archivebox",
        schritte: [
            AblaufSchritt(
                id: 1, title: "Projekt wählen",
                erklaerung: "In der Projekte-Galerie das abzuschließende Projekt öffnen. Archivieren "
                    + "läuft über den Projekt-Kopf."),
            AblaufSchritt(
                id: 2, title: "Bestätigen",
                erklaerung: "Archivieren setzt die Airtable-Phase auf „Archiviert\", verschiebt den "
                    + "Drive-Ordner ins Archiv und markiert die ClickUp-Liste. Ein bewusster Schritt."),
            AblaufSchritt(
                id: 3, title: "Rückholbar",
                erklaerung: "Archiv ist NIE Löschen — Airtable-Daten bleiben (nur ein Status-Feld). "
                    + "Ein archiviertes Projekt lässt sich jederzeit wieder aktiv schalten.")
        ],
        abschlussTitel: "Projekte öffnen",
        abschluss: .modulProjekte)

    public static let alle: [GefuehrterAblauf] = [
        neuesProjekt, sampling, angebotCheckout, aufmass, projektArchivieren
    ]
}
