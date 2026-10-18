import Foundation
import CryptoKit
import AlfaKit

public struct SevdeskPostboxCheckoutPort: CheckoutPort {
    public let id: PortID
    public let name: String

    private let airtableCreate: any AirtableRecordCreating
    private let airtableFetch: any AirtableFetching
    private let baseID: String
    private let belegTable: String
    private let positionTable: String
    private let logger: DataFlowLogger?
    private let jetzt: @Sendable () -> Date

    public static let integrationID = "SEVDESK_POSTBOX_DROP"

    public init(
        id: PortID = PortID("sevdesk-postbox"),
        name: String = "sevDesk-Postbox",
        airtableCreate: any AirtableRecordCreating,
        airtableFetch: any AirtableFetching,

        baseID: String = CompanySetup.valueOrEmpty("airtable.base.sevdesk_postbox"),
        belegTable: String = "Postbox-Beleg",
        positionTable: String = "Postbox-Position",
        logger: DataFlowLogger? = nil,
        jetzt: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.id = id
        self.name = name
        self.airtableCreate = airtableCreate
        self.airtableFetch = airtableFetch
        self.baseID = baseID
        self.belegTable = belegTable
        self.positionTable = positionTable
        self.logger = logger
        self.jetzt = jetzt
    }

    public func erlaubteInhaltsArten() -> Set<InhaltsArt> {
        [.artikel, .material, .dokumente, .gemischt]
    }

    public func preview(basket: WorkBasket, target: PortZiel) async throws -> CheckoutPreview {
        let count = basket.picks.count
        let netto = Self.nettoGegenprobe(basket)
        var warnungen: [String] = []
        if count == 0 {
            warnungen.append("Korb ist leer — es wird kein Beleg abgelegt.")
        }
        let ohneVerkaufspreis = Self.picksOhneVerkaufspreis(basket)
        if ohneVerkaufspreis > 0 {
            warnungen.append(
                "\(ohneVerkaufspreis) Position\(ohneVerkaufspreis == 1 ? "" : "en") ohne Verkaufspreis — "
                + "kein Preis wird übertragen (interner Einkaufspreis verlässt ALPHA nie). Bitte vor der Übergabe prüfen.")
        }
        warnungen.append("sevDesk hat die Hoheit über Mengen, Margen und Steuer — diese Zahlen sind ein Vorschlag.")
        let zusammenfassung =
            "\(Self.belegTyp) mit \(count) Position\(count == 1 ? "" : "en") in die sevDesk-Postbox legen "
            + "(Netto-Gegenprobe \(Self.euro(netto))). Kein Beleg, kein Versand — ein Mensch übernimmt in sevDesk."
        return CheckoutPreview(zusammenfassung: zusammenfassung, warnungen: warnungen)
    }

    public func execute(basket: WorkBasket, target: PortZiel) async throws -> CheckoutResult {
        let start = jetzt()
        let objektHash = Self.objektHash(basket)

        for pick in basket.picks { _ = try await pick.resolve() }

        let postboxID = "PB-" + String(objektHash.prefix(16))
        let belegRecordID: String
        let belegNeu: Bool

        if let vorhandeneID = try await bestehenderBeleg(objektHash: objektHash) {
            belegRecordID = vorhandeneID
            belegNeu = false
        } else {
            let netto = Self.nettoGegenprobe(basket)
            var belegFelder: [String: AirtableFieldValue] = [
                "Postbox-ID": .string(postboxID),
                "Objekt-Hash": .string(objektHash),
                "Status": .string(Self.status),
                "Beleg-Typ": .string(Self.belegTyp),
                "Projekt-Nr": .string(basket.projectNumber),
                "Netto-Summe": .number(netto),
                "Importiert-am": .string(ISO8601DateFormatter().string(from: start))
            ]

            if let pnr = Projektnummer(parsing: basket.projectNumber) {
                belegFelder["sevDesk-Kostenstellen-ID"] = .string(pnr.driveFormat)
            }
            Self.setzeFalls(&belegFelder, "Betreff", target.parameter["betreff"])
            Self.setzeFalls(&belegFelder, "Kunde", target.parameter["kunde"])
            Self.setzeFalls(&belegFelder, "Kundennummer", target.parameter["kundennummer"])

            Self.setzeFalls(&belegFelder, "Adresse Straße", target.parameter["adresseStrasse"])
            Self.setzeFalls(&belegFelder, "Adresse PLZ", target.parameter["adressePLZ"])
            Self.setzeFalls(&belegFelder, "Adresse Ort", target.parameter["adresseOrt"])

            Self.setzeFalls(&belegFelder, "Land", target.parameter["land"])
            Self.setzeFalls(&belegFelder, "sevDesk-Kontakt-ID", target.parameter["sevdeskKontaktID"])
            Self.setzeFalls(&belegFelder, "Zahlungsbedingung (Text)", target.parameter["zahlungsbedingung"])
            if let target = target.parameter["zahlungszielTage"], let tage = Double(target) {
                belegFelder["Zahlungsziel (Tage)"] = .number(tage)
            }

            if let rabatt = target.parameter["gesamtrabatt"], let value = Double(rabatt) {
                belegFelder["Gesamtrabatt %"] = .number(value)
            }

            Self.setzeFalls(&belegFelder, "Abrechnungsart", target.parameter["abrechnungsart"])
            if let art = SevdeskAbrechnungsart.mit(name: target.parameter["abrechnungsart"]) {
                belegFelder["Zahlungs-Fußtext"] = .string(art.fusstext)
                belegFelder["Zahlungsplan"] = .string(art.zahlungsplan)
                belegFelder["sevDesk-TextTemplate-ID"] = .string(art.textTemplateID)
            }

            Self.setzeFalls(&belegFelder, "Kontakt E-Mail", target.parameter["email"])
            Self.setzeFalls(&belegFelder, "Kontakt Telefon", target.parameter["telefon"])
            if let montage = target.parameter["montagekosten"], let value = Double(montage) {
                belegFelder["Montagekosten geplant"] = .number(value)
            }
            Self.setzeFalls(&belegFelder, "Projektbeginn", target.parameter["projektbeginn"])
            Self.setzeFalls(&belegFelder, "Projektende", target.parameter["projektende"])
            Self.setzeFalls(&belegFelder, "Lieferant", target.parameter["lieferant"])
            Self.setzeFalls(&belegFelder, "Fremd-Referenznummer", target.parameter["fremdRef"])
            Self.setzeFalls(&belegFelder, "Quelldatei", basket.picks.first?.snapshot.attribute["quelle"])
            Self.setzeFalls(&belegFelder, "Importiert-von", target.parameter["user"])

            belegRecordID = try await airtableCreate.createRecord(
                baseID: baseID, table: belegTable, fields: belegFelder
            )
            belegNeu = true
        }

        let vorhandenePosNrs = belegNeu ? [] : try await vorhandenePositionsNummern(belegRecordID: belegRecordID)
        var geschrieben = belegNeu ? 1 : 0
        for (index, pick) in basket.picks.enumerated() {
            let posNr = String(index + 1)
            guard vorhandenePosNrs.contains(posNr) == false else { continue }
            let felder = Self.positionsFelder(
                pick: pick, index: index, belegRecordID: belegRecordID, objektHash: objektHash
            )
            _ = try await airtableCreate.createRecord(
                baseID: baseID, table: positionTable, fields: felder
            )
            geschrieben += 1
        }

        let dauerMs = Int(jetzt().timeIntervalSince(start) * 1000)
        let ergaenzt = belegNeu == false && geschrieben > 0

        if belegNeu == false && geschrieben == 0 {
            await protokolliere(
                user: target.parameter["user"] ?? "unbekannt", recordsWritten: 0, durationMs: dauerMs,
                summary: "sevDesk-Postbox: Duplikat (Objekt-Hash bereits vorhanden, alle Positionen vollständig).")
            return CheckoutResult(
                erfolg: true,
                referenz: belegRecordID,
                message: "Bereits in der sevDesk-Postbox (idempotent, kein Duplikat angelegt)."
            )
        }

        await protokolliere(
            user: target.parameter["user"] ?? "unbekannt", recordsWritten: geschrieben, durationMs: dauerMs,
            summary: ergaenzt
                ? "sevDesk-Postbox: \(postboxID) — \(geschrieben) fehlende Position(en) nach Teilfehler ergänzt."
                : "sevDesk-Postbox: \(Self.belegTyp) \(postboxID) mit \(basket.picks.count) Position(en) abgelegt.")

        return CheckoutResult(
            erfolg: true,
            referenz: belegRecordID,
            message: ergaenzt
                ? "In sevDesk-Postbox ergänzt: \(postboxID) (\(geschrieben) fehlende Position(en) nachgeliefert)."
                : "In sevDesk-Postbox abgelegt: \(postboxID) (\(basket.picks.count) Position(en))."
        )
    }

    private func protokolliere(user: String, recordsWritten: Int, durationMs: Int, summary: String) async {
        guard let logger else { return }
        await MainActor.run {
            logger.log(
                integrationID: Self.integrationID, actorUserID: user, action: .success,
                recordsWritten: recordsWritten, durationMs: durationMs, summary: summary)
        }
    }

    private func bestehenderBeleg(objektHash: String) async throws -> String? {
        let records = try await airtableFetch.fetchRecords(baseID: baseID, table: belegTable)
        for record in records where record["Objekt-Hash"]?.stringValue == objektHash {
            return record["_airtableRecordID"]?.stringValue
        }
        return nil
    }

    private func vorhandenePositionsNummern(belegRecordID: String) async throws -> Set<String> {
        let records = try await airtableFetch.fetchRecords(baseID: baseID, table: positionTable)
        var posNrs: Set<String> = []
        for record in records {
            guard case .array(let verlinkteBelege)? = record["Beleg"], verlinkteBelege.contains(belegRecordID) else { continue }
            if let posNr = record["Pos-Nr"]?.stringValue { posNrs.insert(posNr) }
        }
        return posNrs
    }

    static let belegTyp = "Datenpaket für sevdesk-Angebotsentwurf"

    static let status = "Neu (unbestätigt)"

    static func nettoGegenprobe(_ basket: WorkBasket) -> Double {
        basket.picks.reduce(0.0) { sum, pick in
            guard let einzel = pick.snapshot.vkEinzel else { return sum }
            return sum + einzel * Double(pick.snapshot.quantity)
        }
    }

    static func picksOhneVerkaufspreis(_ basket: WorkBasket) -> Int {
        basket.picks.filter { $0.snapshot.vkEinzel == nil }.count
    }

    static func positionsFelder(
        pick: any Pick, index: Int, belegRecordID: String, objektHash: String
    ) -> [String: AirtableFieldValue] {
        let s = pick.snapshot
        let attr = s.attribute

        let einzel = s.vkEinzel
        let posNr = String(index + 1)
        let positionsHash = sha256Hex(Data(("\(objektHash)|\(index)|\(s.label)").utf8))

        var felder: [String: AirtableFieldValue] = [
            "Positions-ID": .string("\(belegRecordID)-P\(posNr)"),
            "Beleg": .array([belegRecordID]),
            "Positions-Hash": .string(positionsHash),
            "Pos-Nr": .string(posNr),
            "Ist-Gruppentitel": .number(0),
            "Titel": .string(s.label),
            "Menge": .number(Double(s.quantity))
        ]

        setzeFalls(&felder, "Beschreibung", attr["beschreibung"] ?? attr["originalText"])
        setzeFalls(&felder, "Artikelnummer", attr["artikelnummer"])
        setzeFalls(&felder, "Einheit", attr["einheit"])
        setzeFalls(&felder, "Richtung", attr["richtung"])

        if let rabatt = attr["rabattProzent"], let value = Double(rabatt) {
            felder["Rabatt %"] = .number(value)
        }

        setzeFalls(&felder, "sevDesk-Artikel-ID", attr["sevdeskArtikelID"])
        if let einzel {
            felder["Einzelpreis"] = .number(einzel)
            felder["Gesamtpreis"] = .number(einzel * Double(s.quantity))
        }
        return felder
    }

    static func objektHash(_ basket: WorkBasket) -> String {
        var teile: [String] = [basket.projectNumber, basket.inhaltsArt.rawValue]
        for pick in basket.picks {
            let s = pick.snapshot
            teile.append([
                pick.objektID.raw,
                s.label,
                String(s.quantity),
                s.vkEinzel.map { String($0) } ?? "",
                s.attribute["artikelnummer"] ?? "",
                s.attribute["originalText"] ?? ""
            ].joined(separator: "|"))
        }
        return sha256Hex(Data(teile.joined(separator: "\n").utf8))
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func euro(_ value: Double) -> String { String(format: "%.2f €", value) }

    static func setzeFalls(_ felder: inout [String: AirtableFieldValue], _ key: String, _ value: String?) {
        guard let value, value.isEmpty == false else { return }
        felder[key] = .string(value)
    }
}
