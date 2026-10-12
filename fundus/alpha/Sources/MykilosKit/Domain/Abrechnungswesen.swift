import Foundation

public enum LeistungsArt: String, Codable, CaseIterable, Sendable {
    case ware
    case planung
    case nachtrag
    case montage
    case sonstige

    public var label: String {
        switch self {
        case .ware: "Ware"
        case .planung: "Planungsleistung"
        case .nachtrag: "Nachtrag"
        case .montage: "Montage"
        case .sonstige: "Sonstiges"
        }
    }
}

public enum AbrechnungsStand: String, Codable, CaseIterable, Sendable {
    case offen
    case gestellt
    case bezahlt

    public var label: String {
        switch self {
        case .offen: "Nicht abgerechnet"
        case .gestellt: "Gestellt, offen"
        case .bezahlt: "Bezahlt"
        }
    }
}

public struct AbrechenbareLeistung: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", art, label = "bezeichnung", betragNetto, belegnummer }

    public let id: String
    public let projectNumber: String
    public let art: LeistungsArt
    public let label: String
    public let betragNetto: Double

    public var belegnummer: String?

    public init(id: String = UUID().uuidString, projectNumber: String, art: LeistungsArt,
                label: String, betragNetto: Double, belegnummer: String? = nil) {
        self.id = id
        self.projectNumber = projectNumber
        self.art = art
        self.label = label
        self.betragNetto = betragNetto
        self.belegnummer = belegnummer
    }
}

public struct AbgerechneterBeleg: Equatable, Sendable {
    public let belegnummer: String

    public let istRechnung: Bool
    public let bezahlt: Bool

    public let betragNetto: Double?

    public init(belegnummer: String, istRechnung: Bool, bezahlt: Bool, betragNetto: Double? = nil) {
        self.belegnummer = belegnummer
        self.istRechnung = istRechnung
        self.bezahlt = bezahlt
        self.betragNetto = betragNetto
    }
}

public enum AbrechnungsAmpel: String, Sendable, Equatable {
    case rot
    case gelb
    case gruen
}

public struct AbrechnungsDeckung: Equatable, Sendable {
    public let nichtAbgerechnet: [AbrechenbareLeistung]

    public let gestelltOffen: [AbrechenbareLeistung]

    public let belegFehlt: [AbrechenbareLeistung]

    public let sollNetto: Double

    public let offenNetto: Double
    public let gestelltNetto: Double
    public let bezahltNetto: Double
    public let anzahlLeistungen: Int

    public let ueberAbgerechnet: [UeberAbrechnung]

    public struct UeberAbrechnung: Equatable, Sendable {
        public let belegnummer: String
        public let belegNetto: Double
        public let gedeckteLeistungenNetto: Double
        public var differenz: Double { belegNetto - gedeckteLeistungenNetto }
    }

    public var ampel: AbrechnungsAmpel {
        if nichtAbgerechnet.isEmpty == false || belegFehlt.isEmpty == false { return .rot }
        if gestelltOffen.isEmpty == false { return .gelb }
        return .gruen
    }

    public var deckungsgrad: Double {
        guard sollNetto > 0 else { return 1 }
        return (gestelltNetto + bezahltNetto) / sollNetto
    }

    public var vollstaendigAbgerechnet: Bool {
        nichtAbgerechnet.isEmpty && belegFehlt.isEmpty && sollNetto > 0
    }

    public func sollJeArt() -> [LeistungsArt: Double] { sollProArt }
    let sollProArt: [LeistungsArt: Double]
}

public enum BetragParser {
    public static func parse(_ text: String) -> Double? {
        let roh = text.trimmingCharacters(in: .whitespaces)
        guard roh.isEmpty == false else { return nil }

        if roh.contains(",") == false {
            let groups = roh.split(separator: ".", omittingEmptySubsequences: false)
            if groups.count > 1,
               groups.allSatisfy({ $0.isEmpty == false && $0.allSatisfy(\.isNumber) }),
               groups.first!.count <= 3,
               groups.dropFirst().allSatisfy({ $0.count == 3 }) {
                guard let value = Double(groups.joined()), value > 0 else { return nil }
                return value
            }

            guard let value = Double(roh), value > 0 else { return nil }
            return value
        }

        let bereinigt = roh
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(bereinigt), value > 0 else { return nil }
        return value
    }
}

public enum AbrechnungsDeckungsCheck {
    public static func pruefe(leistungen: [AbrechenbareLeistung],
                              belege: [AbgerechneterBeleg]) -> AbrechnungsDeckung {
        var belegNach: [String: AbgerechneterBeleg] = [:]
        for beleg in belege where belegNach[beleg.belegnummer] == nil {
            belegNach[beleg.belegnummer] = beleg
        }

        var nichtAbgerechnet: [AbrechenbareLeistung] = []
        var gestelltOffen: [AbrechenbareLeistung] = []
        var belegFehlt: [AbrechenbareLeistung] = []
        var sollNetto = 0.0, offenNetto = 0.0, gestelltNetto = 0.0, bezahltNetto = 0.0
        var sollProArt: [LeistungsArt: Double] = [:]

        var gedecktJeBeleg: [String: Double] = [:]

        for leistung in leistungen {
            sollNetto += leistung.betragNetto
            sollProArt[leistung.art, default: 0] += leistung.betragNetto

            let number = (leistung.belegnummer ?? "").trimmingCharacters(in: .whitespaces)
            if number.isEmpty {
                nichtAbgerechnet.append(leistung)
                offenNetto += leistung.betragNetto
            } else if let beleg = belegNach[number], beleg.istRechnung {
                gedecktJeBeleg[number, default: 0] += leistung.betragNetto
                if beleg.bezahlt {
                    bezahltNetto += leistung.betragNetto
                } else {
                    gestelltOffen.append(leistung)
                    gestelltNetto += leistung.betragNetto
                }
            } else {
                belegFehlt.append(leistung)
                offenNetto += leistung.betragNetto
            }
        }

        var ueber: [AbrechnungsDeckung.UeberAbrechnung] = []
        for beleg in belege where beleg.istRechnung {
            guard let belegNetto = beleg.betragNetto else { continue }
            let gedeckt = gedecktJeBeleg[beleg.belegnummer] ?? 0
            if belegNetto - gedeckt > 0.005 {
                ueber.append(.init(belegnummer: beleg.belegnummer,
                                   belegNetto: belegNetto,
                                   gedeckteLeistungenNetto: gedeckt))
            }
        }

        return AbrechnungsDeckung(
            nichtAbgerechnet: nichtAbgerechnet.sorted { $0.label < $1.label },
            gestelltOffen: gestelltOffen.sorted { $0.label < $1.label },
            belegFehlt: belegFehlt.sorted { $0.label < $1.label },
            sollNetto: sollNetto,
            offenNetto: offenNetto,
            gestelltNetto: gestelltNetto,
            bezahltNetto: bezahltNetto,
            anzahlLeistungen: leistungen.count,
            ueberAbgerechnet: ueber.sorted { $0.belegnummer < $1.belegnummer },
            sollProArt: sollProArt)
    }
}
