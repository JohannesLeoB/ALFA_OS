import Foundation

public struct ControllingBeleg: Sendable, Equatable {
    public let belegnummer: String

    public let belegArt: String
    public let betragNetto: Double?
    public let bezahlt: Bool

    public let auftrag: WorkBasketID?

    public init(belegnummer: String, belegArt: String, betragNetto: Double? = nil,
                bezahlt: Bool = false, auftrag: WorkBasketID? = nil) {
        self.belegnummer = belegnummer
        self.belegArt = belegArt
        self.betragNetto = betragNetto
        self.bezahlt = bezahlt
        self.auftrag = auftrag
    }
}

public struct AuftragsBild: Sendable, Identifiable {
    public let kette: AuftragsKette

    public let deckung: BestellDeckung

    public let belege: [ControllingBeleg]

    public let gaps: [String]

    public var id: String { kette.id }

    public var abVorhanden: Bool { belege.contains { $0.belegArt == "AB" } }
    public var rechnungenNetto: Double {
        belege.filter { $0.belegArt == "RE" }.compactMap(\.betragNetto).reduce(0, +)
    }
    public var bezahltNetto: Double {
        belege.filter { $0.belegArt == "RE" && $0.bezahlt }.compactMap(\.betragNetto).reduce(0, +)
    }

    public var offenerAuftragswert: Double? {
        guard belege.contains(where: { $0.belegArt == "RE" }) else { return nil }
        return kette.auftragswert - rechnungenNetto
    }
}

public enum AuftragsControlling {
    public static func images(
        koerbe: [WorkBasket],
        orders: [Order],
        belege: [ControllingBeleg],
        eingangsrechnungenVerfuegbar: Bool = false
    ) -> (images: [AuftragsBild], verwaist: [WorkBasketID]) {
        let (ketten, verwaist) = AuftragsKettenRechner.ketten(aus: koerbe)
        let koerbeNachID = Dictionary(uniqueKeysWithValues: koerbe.map { ($0.id, $0) })

        let images = ketten.map { kette -> AuftragsBild in

            let ids = [kette.root] + kette.fortfuehrungen
            var sums: [String: (label: String, quantity: Int)] = [:]
            for id in ids {
                guard let korb = koerbeNachID[id] else { continue }
                for pick in korb.picks {
                    let key = pick.objektID.raw
                    let bisher = sums[key]?.quantity ?? 0
                    sums[key] = (pick.snapshot.label, bisher + pick.snapshot.quantity)
                }
            }
            let korbPositionen = sums.map {
                BestellKorbPosition(objektID: $0.key, label: $0.value.label, quantity: $0.value.quantity)
            }.sorted { $0.label < $1.label }

            let eigeneIDs = Set(sums.keys)
            let eigeneBestellungen = orders.filter { order in
                order.positionen.contains { eigeneIDs.contains($0.objektID) }
            }
            let deckung = BestellDeckungsCheck.pruefe(korb: korbPositionen, orders: eigeneBestellungen)

            let eigeneBelege = belege.filter { $0.auftrag == kette.root }

            var gaps: [String] = []
            if eigeneBelege.contains(where: { $0.belegArt == "AB" }) == false {
                gaps.append("Keine Auftragsbestätigung zugeordnet — der Auftragswert ist "
                               + "die bestätigte Kalkulation, nicht ein kaufmännisch gesicherter Wert.")
            }
            if eigeneBelege.contains(where: { $0.belegArt == "RE" }) == false {
                gaps.append("Keine Rechnung zugeordnet — „offen\" ist unbekannt, nicht gleich dem Auftragswert.")
            }

            if kette.marge == nil {
                gaps.append("Kein Einkaufspreis an den Positionen — die Marge ist unbekannt, "
                               + "nicht gleich dem Auftragswert.")
            } else if kette.margeVollstaendig == false {
                gaps.append("\(kette.positionenOhneEK) Position(en) ohne Einkaufspreis — "
                               + "die Marge ist zu gut ausgewiesen.")
            }
            if eingangsrechnungenVerfuegbar == false {
                gaps.append("Eingangsrechnungen (die tatsächlich gezahlten Kosten) werden noch "
                               + "nicht gelesen — verglichen wird gegen den EK aus dem Angebot, "
                               + "nicht gegen die Rechnung des Lieferanten.")
            }
            let ohneVK = ids.compactMap { koerbeNachID[$0] }
                .reduce(0) { $0 + AuftragsKettenRechner.positionenOhneVK($1) }
            if ohneVK > 0 {
                gaps.append("\(ohneVK) Position(en) ohne Verkaufspreis — der Auftragswert ist unvollständig.")
            }

            return AuftragsBild(kette: kette, deckung: deckung, belege: eigeneBelege, gaps: gaps)
        }
        return (images, verwaist)
    }

    public static func projektAuftragswert(_ images: [AuftragsBild]) -> Double {
        images.reduce(0) { $0 + $1.kette.auftragswert }
    }
}
