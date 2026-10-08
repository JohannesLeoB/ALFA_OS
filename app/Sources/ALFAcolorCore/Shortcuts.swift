// Tastenkarte (B-106): Menübefehle, Kürzel und Vorlagen als reine Daten.
// Ohne SwiftUI, damit `swift test` die Tabelle prüfen kann. Die Menüs in
// ALFAcolor/App/Commands/ übersetzen die Einträge in Bedienung.
// Quellen: konzept/05-OBERFLAECHE.txt Abschnitt 4 (Menüs) und 5 (Werkzeuge);
// konzept/02-NUTZER.txt Abschnitt 6 (Kollisionen mit macOS);
// konzept/09-VISION-AUSFUEHRLICH.md Abschnitt 4 (Werkzeugtasten).

/// Ein Menü der Menüleiste. `werkzeug` steht nur in der Tastenkarte; das Werkzeugmenü baut B-305.
public enum Menue: String, CaseIterable, Hashable, Sendable {
    case ablage, bearbeiten, objekt, darstellung, fenster, hilfe, werkzeug

    public var titel: String {
        switch self {
        case .ablage: "Ablage"
        case .bearbeiten: "Bearbeiten"
        case .objekt: "Objekt"
        case .darstellung: "Darstellung"
        case .fenster: "Fenster"
        case .hilfe: "Hilfe"
        case .werkzeug: "Werkzeug"
        }
    }
}

/// Modifikatortasten. Die Anzeige folgt der macOS-Reihenfolge ⌃⌥⇧⌘.
public struct Modifikatoren: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = Modifikatoren(rawValue: 1 << 0)
    public static let option = Modifikatoren(rawValue: 1 << 1)
    public static let umschalt = Modifikatoren(rawValue: 1 << 2)
    public static let befehl = Modifikatoren(rawValue: 1 << 3)
}

/// Ein Tastenkürzel: Modifikatoren und eine Taste. Buchstaben werden in Großschrift gespeichert.
public struct Kuerzel: Hashable, Sendable {
    public let modifikatoren: Modifikatoren
    public let taste: String

    public init(_ modifikatoren: Modifikatoren, _ taste: String) {
        self.modifikatoren = modifikatoren
        self.taste = taste.uppercased()
    }

    /// Anzeige wie im Menü, zum Beispiel "⌥⌘1" oder "⇧⌘]".
    public var anzeige: String {
        var text = ""
        if modifikatoren.contains(.control) { text += "⌃" }
        if modifikatoren.contains(.option) { text += "⌥" }
        if modifikatoren.contains(.umschalt) { text += "⇧" }
        if modifikatoren.contains(.befehl) { text += "⌘" }
        return text + taste
    }
}

/// Woher die Taste stammt: macOS-Standard, InDesign (Erinnerung, nicht geprüft) oder ein Vorschlag von ALFAcolor.
public enum Vorlage: String, Hashable, Sendable {
    case macOS, inDesign, vorschlag

    public var titel: String {
        switch self {
        case .macOS: "macOS"
        case .inDesign: "InDesign"
        case .vorschlag: "Vorschlag"
        }
    }
}

/// `immer`: das Kürzel gilt überall. `nurLeinwand`: nur bei Fokus auf der Leinwand und ohne Textfeld (B-305 bindet die Tasten).
public enum Geltung: String, Hashable, Sendable {
    case immer, nurLeinwand
}

/// `eigen`: ALFAcolor legt den Eintrag an. `system`: macOS oder SwiftUI liefert ihn; er steht nur in der Tastenkarte.
public enum Herkunft: String, Hashable, Sendable {
    case eigen, system
}

/// Ein Menübefehl mit Kürzel. `id` ist eindeutig und dient dazu, die Funktion zuzuordnen.
public struct Befehl: Identifiable, Hashable, Sendable {
    public let id: String
    public let menue: Menue
    public let titel: String
    public let kuerzel: Kuerzel?
    public let vorlage: Vorlage
    public let geltung: Geltung
    public let herkunft: Herkunft
    /// Untermenü, zu dem der Eintrag gehört (z. B. "Ausrichten"); nil für Einträge direkt im Menü.
    public let untermenue: String?
    /// Trennlinie vor dem Eintrag.
    public let trennerDavor: Bool
}

/// Ein Glied eines Menüs in Anzeigereihenfolge.
public enum Posten: Identifiable, Sendable {
    case trenner(Int)
    case eintrag(Befehl)
    case untermenue(titel: String, eintraege: [Befehl])

    public var id: String {
        switch self {
        case .trenner(let n): "trenner-\(n)"
        case .eintrag(let befehl): befehl.id
        case .untermenue(let titel, _): "untermenue-\(titel)"
        }
    }
}

/// Die Tabelle aller Befehle: Befehl → Taste → Vorlage. Eine Quelle für Menüs und Tastenkarte.
public enum Tastenkarte {
    public static let befehle: [Befehl] = ablage + bearbeiten + darstellung + objekt + fenster + hilfe + werkzeug

    /// Die Glieder eines Menüs. Ohne `herkunft` alle Einträge, sonst nur die mit dieser Herkunft.
    /// Trennlinien stehen nie am Anfang; Einträge mit gleichem `untermenue` fasst die Liste zusammen.
    public static func posten(_ menue: Menue, herkunft: Herkunft? = nil) -> [Posten] {
        var ergebnis: [Posten] = []
        for befehl in befehle where befehl.menue == menue && (herkunft == nil || befehl.herkunft == herkunft) {
            if befehl.trennerDavor && !ergebnis.isEmpty {
                ergebnis.append(.trenner(ergebnis.count))
            }
            if let titel = befehl.untermenue {
                if case .untermenue(let offen, let eintraege)? = ergebnis.last, offen == titel {
                    ergebnis[ergebnis.count - 1] = .untermenue(titel: offen, eintraege: eintraege + [befehl])
                } else {
                    ergebnis.append(.untermenue(titel: titel, eintraege: [befehl]))
                }
            } else {
                ergebnis.append(.eintrag(befehl))
            }
        }
        return ergebnis
    }

    static let ablage: [Befehl] = [
        befehl("ablage.neu", .ablage, "Neues Dokument", "N", [.befehl], vorlage: .macOS),
        befehl("ablage.oeffnen", .ablage, "Öffnen…", "O", [.befehl], vorlage: .macOS),
        befehl("ablage.zuletzt", .ablage, "Zuletzt geöffnet"),
        befehl("ablage.schliessen", .ablage, "Schließen", "W", [.befehl], vorlage: .macOS, herkunft: .system, trenner: true),
        befehl("ablage.sichern", .ablage, "Sichern", "S", [.befehl], vorlage: .macOS, trenner: true),
        befehl("ablage.duplizieren", .ablage, "Duplizieren", "S", [.befehl, .umschalt], vorlage: .macOS),
        befehl("ablage.umbenennen", .ablage, "Umbenennen…"),
        befehl("ablage.verschieben", .ablage, "Verschieben nach…"),
        befehl("ablage.ausgeben", .ablage, "Ausgeben…", "E", [.befehl, .umschalt], trenner: true),
        befehl("ablage.zuruecksetzen", .ablage, "Auf Version zurücksetzen"),
        befehl("ablage.seite", .ablage, "Seite einrichten…", "P", [.befehl, .umschalt], vorlage: .macOS, trenner: true),
        befehl("ablage.drucken", .ablage, "Drucken…", "P", [.befehl], vorlage: .macOS),
    ]

    static let bearbeiten: [Befehl] = [
        befehl("bearbeiten.rueckgaengig", .bearbeiten, "Rückgängig", "Z", [.befehl], vorlage: .macOS, herkunft: .system),
        befehl("bearbeiten.wiederholen", .bearbeiten, "Wiederholen", "Z", [.befehl, .umschalt], vorlage: .macOS, herkunft: .system),
        befehl("bearbeiten.ausschneiden", .bearbeiten, "Ausschneiden", "X", [.befehl], vorlage: .macOS, herkunft: .system, trenner: true),
        befehl("bearbeiten.kopieren", .bearbeiten, "Kopieren", "C", [.befehl], vorlage: .macOS, herkunft: .system),
        befehl("bearbeiten.einsetzen", .bearbeiten, "Einsetzen", "V", [.befehl], vorlage: .macOS, herkunft: .system),
        befehl("bearbeiten.einsetzenStil", .bearbeiten, "Einsetzen und Stil anpassen", "V", [.option, .umschalt, .befehl], vorlage: .macOS),
        befehl("bearbeiten.stilEinsetzen", .bearbeiten, "Stil einsetzen", "V", [.option, .befehl], vorlage: .macOS),
        befehl("bearbeiten.loeschen", .bearbeiten, "Löschen", "⌫", [], vorlage: .macOS, geltung: .nurLeinwand),
        befehl("bearbeiten.alleAuswaehlen", .bearbeiten, "Alles auswählen", "A", [.befehl], vorlage: .macOS, herkunft: .system, trenner: true),
        befehl("bearbeiten.auswahlAufheben", .bearbeiten, "Auswahl aufheben", "A", [.befehl, .umschalt], vorlage: .macOS),
        befehl("bearbeiten.suchen", .bearbeiten, "Suchen…", "F", [.befehl], vorlage: .macOS, trenner: true),
    ]

    static let darstellung: [Befehl] = [
        befehl("darstellung.seitenleiste", .darstellung, "Seitenleiste ein/aus", "1", [.option, .befehl]),
        befehl("darstellung.inspektor", .darstellung, "Inspektor ein/aus", "0", [.option, .befehl]),
        befehl("darstellung.alle", .darstellung, "Alle Panels ein/aus", trenner: true),
        befehl("darstellung.statusleiste", .darstellung, "Statusleiste ein/aus"),
        befehl("darstellung.werkzeugleiste", .darstellung, "Werkzeugleiste ein/aus", "T", [.option, .befehl], vorlage: .macOS, herkunft: .system, trenner: true),
        befehl("darstellung.werkzeugOptionen", .darstellung, "Werkzeugoptionen ein/aus"),
        befehl("darstellung.zoomEin", .darstellung, "Vergrößern", "=", [.befehl], trenner: true),
        befehl("darstellung.zoomAus", .darstellung, "Verkleinern", "-", [.befehl]),
        befehl("darstellung.originalgroesse", .darstellung, "Originalgröße", "0", [.befehl]),
        befehl("darstellung.auswahlEinpassen", .darstellung, "Auswahl einpassen", "9", [.befehl]),
        befehl("darstellung.alleEinpassen", .darstellung, "Alles einpassen", "1", [.befehl]),
        befehl("darstellung.raster", .darstellung, "Raster ein/aus", "R", [.option, .befehl], trenner: true),
        befehl("darstellung.hilfslinien", .darstellung, "Hilfslinien ein/aus", "L", [.option, .befehl]),
        befehl("darstellung.einrasten", .darstellung, "Am Raster einrasten", "R", [.befehl, .umschalt]),
        befehl("darstellung.vollbild", .darstellung, "Vollbild aktivieren", "F", [.control, .befehl], vorlage: .macOS, herkunft: .system, trenner: true),
    ]

    static let objekt: [Befehl] = [
        befehl("objekt.gruppieren", .objekt, "Gruppieren", "G", [.befehl]),
        befehl("objekt.gruppierungAufheben", .objekt, "Gruppierung aufheben", "G", [.befehl, .umschalt]),
        befehl("objekt.duplizieren", .objekt, "Duplizieren", "D", [.befehl], vorlage: .inDesign),
        befehl("objekt.nachVorne", .objekt, "Nach vorne", "]", [.befehl, .umschalt], unter: "Anordnen", trenner: true),
        befehl("objekt.nachHinten", .objekt, "Nach hinten", "[", [.befehl, .umschalt], unter: "Anordnen"),
        befehl("objekt.ganzNachVorne", .objekt, "Ganz nach vorne", "]", [.option, .befehl, .umschalt], unter: "Anordnen"),
        befehl("objekt.links", .objekt, "Links", unter: "Ausrichten", trenner: true),
        befehl("objekt.hMitte", .objekt, "Horizontal zentriert", unter: "Ausrichten"),
        befehl("objekt.rechts", .objekt, "Rechts", unter: "Ausrichten"),
        befehl("objekt.oben", .objekt, "Oben", unter: "Ausrichten"),
        befehl("objekt.vMitte", .objekt, "Vertikal zentriert", unter: "Ausrichten"),
        befehl("objekt.unten", .objekt, "Unten", unter: "Ausrichten"),
        befehl("objekt.reihe", .objekt, "Reihe", unter: "Verteilen", trenner: true),
        befehl("objekt.verteilRaster", .objekt, "Raster", unter: "Verteilen"),
        befehl("objekt.haufen", .objekt, "Haufen", unter: "Verteilen"),
        befehl("objekt.gleicheGroesse", .objekt, "Gleiche Größe", trenner: true),
        befehl("objekt.anRaster", .objekt, "An Raster ausrichten"),
        befehl("objekt.inRahmen", .objekt, "In Rahmen einpassen…"),
    ]

    static let fenster: [Befehl] = [
        befehl("fenster.minimieren", .fenster, "Minimieren", "M", [.befehl], vorlage: .macOS, herkunft: .system),
        befehl("fenster.alleMinimieren", .fenster, "Alle minimieren", "M", [.option, .befehl], vorlage: .macOS, herkunft: .system),
        befehl("fenster.zoomen", .fenster, "Zoomen", herkunft: .system),
        befehl("fenster.werkzeuge", .fenster, "Werkzeuge ein/aus", "P", [.option, .befehl], trenner: true),
        befehl("fenster.ebenen", .fenster, "Ebenen ein/aus"),
        befehl("fenster.sammlung", .fenster, "Sammlung ein/aus"),
        befehl("fenster.allesNachVorne", .fenster, "Alle nach vorne bringen", herkunft: .system, trenner: true),
        befehl("fenster.vorheriges", .fenster, "Vorheriges Fenster", "`", [.befehl], vorlage: .macOS, herkunft: .system),
        befehl("fenster.naechstes", .fenster, "Nächstes Fenster", "`", [.befehl, .umschalt], vorlage: .macOS, herkunft: .system),
    ]

    static let hilfe: [Befehl] = [
        befehl("hilfe.hilfe", .hilfe, "ALFAcolor-Hilfe", "?", [.befehl]),
        befehl("hilfe.tastenkarte", .hilfe, "Tastenkarte", trenner: true),
    ]

    /// Einzeltasten der Werkzeuge (09-VISION Abschnitt 4). Ohne Befehlstaste, daher nur auf der Leinwand.
    static let werkzeug: [Befehl] = [
        befehl("werkzeug.auswahl", .werkzeug, "Auswahl", "V", vorlage: .inDesign, geltung: .nurLeinwand),
        befehl("werkzeug.direkt", .werkzeug, "Direktauswahl", "A", vorlage: .inDesign, geltung: .nurLeinwand),
        befehl("werkzeug.rahmen", .werkzeug, "Rahmen", "F", geltung: .nurLeinwand),
        befehl("werkzeug.form", .werkzeug, "Form", "U", geltung: .nurLeinwand),
        befehl("werkzeug.text", .werkzeug, "Text", "T", geltung: .nurLeinwand),
        befehl("werkzeug.hand", .werkzeug, "Hand", "H", vorlage: .inDesign, geltung: .nurLeinwand),
        befehl("werkzeug.zoom", .werkzeug, "Zoom", "Z", vorlage: .inDesign, geltung: .nurLeinwand),
        befehl("werkzeug.pipette", .werkzeug, "Pipette", "I", geltung: .nurLeinwand),
        befehl("werkzeug.messen", .werkzeug, "Messen", "M", geltung: .nurLeinwand),
        befehl("werkzeug.stift", .werkzeug, "Stift", "P", geltung: .nurLeinwand),
        befehl("werkzeug.kommentar", .werkzeug, "Kommentar", "C", geltung: .nurLeinwand),
        befehl("werkzeug.labor", .werkzeug, "Labor", "L", geltung: .nurLeinwand),
    ]

    /// Kurzform für die Tabelle. Ohne `taste` gibt es kein Kürzel.
    private static func befehl(
        _ id: String,
        _ menue: Menue,
        _ titel: String,
        _ taste: String? = nil,
        _ modifikatoren: Modifikatoren = [],
        vorlage: Vorlage = .vorschlag,
        geltung: Geltung = .immer,
        herkunft: Herkunft = .eigen,
        unter: String? = nil,
        trenner: Bool = false
    ) -> Befehl {
        Befehl(
            id: id,
            menue: menue,
            titel: titel,
            kuerzel: taste.map { Kuerzel(modifikatoren, $0) },
            vorlage: vorlage,
            geltung: geltung,
            herkunft: herkunft,
            untermenue: unter,
            trennerDavor: trenner
        )
    }
}
