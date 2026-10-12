import Foundation

public struct MykKeyCombo: Codable, Equatable, Hashable, Sendable {
    public let taste: String
    public let command: Bool
    public let shift: Bool
    public let option: Bool
    public let control: Bool

    public init(_ taste: String, command: Bool = false, shift: Bool = false,
                option: Bool = false, control: Bool = false) {
        self.taste = taste.lowercased()
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    public var hatModifier: Bool { command || shift || option || control }

    public var display: String {
        var s = ""
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        return s + taste.uppercased()
    }
}

public enum TastenkuerzelAktion: String, Codable, CaseIterable, Sendable, Identifiable {
    case oeffneEinstellungen
    case modulHeute
    case modulProjekte
    case modulAssistent
    case modulKataloge
    case modulPapers

    case modulCash
    case modulService
    case modulWerkstatt
    case modulMail
    case modulStudio

    case werkzeugHubZuruecksetzen
    case oeffneLaunchpad
    case zurueck
    case vollbild
    case falteLinkeSpalte
    case falteRechteSpalte

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .oeffneEinstellungen: "Einstellungen öffnen"
        case .modulHeute:          "Modul: Heute"
        case .modulProjekte:       "Modul: Projekte"
        case .modulAssistent:      "Modul: Assistent"
        case .modulKataloge:       "Modul: Kataloge"
        case .modulPapers:         "Modul: Papers"
        case .modulCash:           "Modul: Cash"
        case .modulService:        "Modul: Service"
        case .modulStudio:         "Modul: Studio"
        case .modulWerkstatt:      "Modul: Werkstatt"
        case .modulMail:           "Modul: Mail"
        case .werkzeugHubZuruecksetzen: "Werkzeug-Knopf zurücksetzen"
        case .oeffneLaunchpad:     "Launchpad öffnen"
        case .zurueck:             "Zurück"
        case .vollbild:            "Vollbild"
        case .falteLinkeSpalte:    "Linke Spalte ein-/ausblenden"
        case .falteRechteSpalte:   "Rechte Spalte ein-/ausblenden"
        }
    }

    public var standard: MykKeyCombo {
        switch self {
        case .oeffneEinstellungen: MykKeyCombo(",", command: true)
        case .modulHeute:          MykKeyCombo("1", command: true)
        case .modulProjekte:       MykKeyCombo("2", command: true)
        case .modulAssistent:      MykKeyCombo("3", command: true)
        case .modulKataloge:       MykKeyCombo("4", command: true)
        case .modulPapers:         MykKeyCombo("5", command: true)
        case .modulCash:           MykKeyCombo("6", command: true)
        case .modulService:        MykKeyCombo("7", command: true)
        case .modulWerkstatt:      MykKeyCombo("8", command: true)
        case .modulMail:           MykKeyCombo("9", command: true)
        case .modulStudio:         MykKeyCombo("0", command: true)
        case .werkzeugHubZuruecksetzen: MykKeyCombo("h", command: true, option: true)
        case .oeffneLaunchpad:     MykKeyCombo("a", command: true, shift: true)
        case .zurueck:             MykKeyCombo("[", command: true)
        case .vollbild:            MykKeyCombo("f", command: true, control: true)
        case .falteLinkeSpalte:    MykKeyCombo("s", command: true, control: true)
        case .falteRechteSpalte:   MykKeyCombo("s", command: true, option: true)
        }
    }
}

public struct TastenkuerzelBelegungen: Codable, Equatable, Sendable {
    public private(set) var ueberschreibungen: [TastenkuerzelAktion: MykKeyCombo]

    public init(ueberschreibungen: [TastenkuerzelAktion: MykKeyCombo] = [:]) {
        self.ueberschreibungen = ueberschreibungen
    }

    public func combo(fuer action: TastenkuerzelAktion) -> MykKeyCombo {
        ueberschreibungen[action] ?? action.standard
    }

    public func istGeaendert(_ action: TastenkuerzelAktion) -> Bool {
        ueberschreibungen[action] != nil
    }

    public func kollision(fuer combo: MykKeyCombo, ausser action: TastenkuerzelAktion) -> TastenkuerzelAktion? {
        TastenkuerzelAktion.allCases.first { andere in
            andere != action && self.combo(fuer: andere) == combo
        }
    }

    public mutating func setze(_ action: TastenkuerzelAktion, auf combo: MykKeyCombo) throws {
        guard combo.hatModifier else { throw TastenkuerzelFehler.ohneModifier }
        if let konflikt = kollision(fuer: combo, ausser: action) {
            throw TastenkuerzelFehler.belegt(durch: konflikt)
        }

        if combo == action.standard { ueberschreibungen.removeValue(forKey: action) } else { ueberschreibungen[action] = combo }
    }

    public mutating func reset(_ action: TastenkuerzelAktion) {
        ueberschreibungen.removeValue(forKey: action)
    }

    public mutating func allesZuruecksetzen() {
        ueberschreibungen.removeAll()
    }
}

public enum TastenkuerzelFehler: Error, Equatable, Sendable {
    case ohneModifier
    case belegt(durch: TastenkuerzelAktion)

    public var beschreibung: String {
        switch self {
        case .ohneModifier: "Ein globales Kürzel braucht mindestens einen Modifier (⌘, ⌥, ⌃ oder ⇧)."
        case .belegt(let a): "Dieses Kürzel ist schon mit „\(a.displayName)“ belegt."
        }
    }
}

extension TastenkuerzelBelegungen {
    private enum CodingKeys: String, CodingKey { case ueberschreibungen }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let roh = try c.decodeIfPresent([String: MykKeyCombo].self, forKey: .ueberschreibungen) ?? [:]
        var map: [TastenkuerzelAktion: MykKeyCombo] = [:]
        for (key, combo) in roh {
            if let action = TastenkuerzelAktion(rawValue: key) { map[action] = combo }
        }
        self.init(ueberschreibungen: map)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let roh = Dictionary(uniqueKeysWithValues: ueberschreibungen.map { ($0.key.rawValue, $0.value) })
        try c.encode(roh, forKey: .ueberschreibungen)
    }
}
