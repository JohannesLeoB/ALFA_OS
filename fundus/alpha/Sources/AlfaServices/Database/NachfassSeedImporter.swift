import Foundation
import AlfaKit

public struct NachfassSeedImporter {
    public struct Ergebnis: Sendable, Equatable {
        public var importiert: Int
        public var uebersprungen: Int
        public var weclappGefunden: Bool
        public var slackGefunden: Bool
        public var error: String?
    }

    static let keineKunden: Set<String> = ["a_anfragen_projekte", "a_anfragen_produkte"]

    static let regionen: Set<String> = ["hh", "b", "sa", "ber", "ol", "siz", "be", "bw"]

    static var channelInitials: Set<String> { Set(ChannelInitials.current) }

    private let store: NachfassFallStore

    public init(store: NachfassFallStore) {
        self.store = store
    }

    public func importiere(heute: Date = Date()) async -> Ergebnis {
        var result = Ergebnis(importiert: 0, uebersprungen: 0,
                                weclappGefunden: false, slackGefunden: false, error: nil)

        let vorhanden: Set<String>
        do { vorhanden = try await store.vorhandeneIDs() } catch { return Ergebnis(importiert: 0, uebersprungen: 0, weclappGefunden: false,
                                slackGefunden: false, error: error.localizedDescription) }

        var candidates: [NachfassFall] = []

        if let data = Self.ladeRessource(name: "nachfass_seed_weclapp"),
           let rowItems = try? JSONDecoder().decode([WeclappSeed].self, from: data) {
            result.weclappGefunden = true
            let aktuellsteProAngebot = Dictionary(grouping: rowItems, by: { $0.angebot })
                .compactMapValues { rows in
                    rows.max { a, b in
                        let da = Self.datum(a.datum) ?? .distantPast
                        let db = Self.datum(b.datum) ?? .distantPast
                        if da != db { return da < db }
                        return a.netto < b.netto
                    }
                }
            for z in aktuellsteProAngebot.values.sorted(by: { $0.angebot < $1.angebot }) {
                let datum = Self.datum(z.datum)
                candidates.append(NachfassFall(
                    id: "seed-wec-\(z.angebot)",
                    source: .angebot,
                    customerName: z.kunde.trimmingCharacters(in: .whitespaces),
                    customerNumber: z.kundennr,
                    value: z.netto,
                    angebotsNummer: z.angebot,
                    angebotsDatum: datum,
                    letzterKontakt: nil,
                    naechstesNachfassen: datum.map { NachfassAuswertung.naechsterTermin(basis: $0) },
                    status: .offen))
            }
        }

        if let data = Self.ladeRessource(name: "nachfass_seed_slack"),
           let rowItems = try? JSONDecoder().decode([SlackSeed].self, from: data) {
            result.slackGefunden = true
            for z in rowItems where Self.keineKunden.contains(z.kanal) == false {
                let letzte = Self.datum(z.letzteAktivitaet)
                let stand = z.letzterStand.joined(separator: "\n")
                let notiz = "Slack \(z.kanal) · \(z.nachrichten) Nachrichten"
                    + (stand.isEmpty ? "" : "\n\(stand)")
                candidates.append(NachfassFall(
                    id: "seed-slk-\(z.kanal)",
                    source: .slackImport,
                    customerName: Self.kundeAusKanal(z.kanal),
                    letzterKontakt: letzte.map { NachfassKontakt(date: $0, kanal: .slack) },
                    naechstesNachfassen: letzte.map { NachfassAuswertung.naechsterTermin(basis: $0) },
                    status: .offen,
                    notizen: notiz))
            }
        }

        let neu = candidates.filter { vorhanden.contains($0.id) == false }
        result.uebersprungen = candidates.count - neu.count
        if neu.isEmpty == false {
            do { try await store.speichereAlle(neu); result.importiert = neu.count } catch { result.error = error.localizedDescription }
        }
        return result
    }

    static func kundeAusKanal(_ kanal: String) -> String {
        var teile = kanal.lowercased().split(separator: "_").map(String.init)
        if teile.first == "a" { teile.removeFirst() }
        if let erst = teile.first, regionen.contains(erst) { teile.removeFirst() }
        if let letzt = teile.last, channelInitials.contains(letzt) { teile.removeLast() }
        let name = teile.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard name.isEmpty == false else { return kanal }
        return name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func ladeRessource(name: String) -> Data? {
        guard let url = StudioBrain.sichereRessourcenURL(name: name, ext: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    private static let isoTag: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func datum(_ roh: String) -> Date? { isoTag.date(from: roh) }

    private struct WeclappSeed: Decodable {
        let angebot: String
        let datum: String
        let kunde: String
        let kundennr: String
        let netto: Double
        let alterTage: Int
        enum CodingKeys: String, CodingKey {
            case angebot, datum, kunde, kundennr, netto
            case alterTage = "alter_tage"
        }
    }

    private struct SlackSeed: Decodable {
        let kanal: String
        let angelegt: String
        let letzteAktivitaet: String
        let tageStill: Int
        let nachrichten: Int
        let letzterStand: [String]
        enum CodingKeys: String, CodingKey {
            case kanal, angelegt, nachrichten
            case letzteAktivitaet = "letzte_aktivitaet"
            case tageStill = "tage_still"
            case letzterStand = "letzter_stand"
        }
    }
}
