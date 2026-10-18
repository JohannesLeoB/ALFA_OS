import Foundation
import GRDB
import AlfaKit

struct ClockodoEchteBuchungRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "clockodoEchteBuchungen" }
    var zeilenID: String
    var clockodoEntryID: String
    var gebuchtAm: Double
    var userID: String
}

@MainActor
@Observable
public final class ClockodoZeitTabelleStore {
    public var manuelleZeilen: [ClockodoZeitZeile] = []
    public private(set) var gebuchteIDs: Set<UUID> = []
    public private(set) var zustandJeZeile: [UUID: SaveState] = [:]

    public private(set) var kunden: [ClockodoKunde] = []
    public private(set) var projekte: [ClockodoProjekt] = []
    public private(set) var leistungen: [ClockodoLeistung] = []

    public private(set) var gebuchteEintraege: [ClockodoEintrag] = []
    public private(set) var stammdatenFehler: String?

    public var zeitraum: ClockodoZeitraum = .woche
    public private(set) var zustandJeEintrag: [Int: SaveState] = [:]

    private let db: GRDBDatabase
    private let booking: ClockodoBooking
    private let stammdaten: ClockodoStammdatenFetching
    private let dataFlow: DataFlowLogger?
    private let actorUserID: String
    private let userID: String?

    private let clockodoUserID: Int?

    public init(
        db: GRDBDatabase, booking: ClockodoBooking = ClockodoClient(),
        stammdaten: ClockodoStammdatenFetching = ClockodoClient(),
        dataFlow: DataFlowLogger? = nil, actorUserID: String = "",
        userID: String? = CurrentUserContext.current,
        clockodoUserID: Int? = nil
    ) {
        self.db = db
        self.booking = booking
        self.stammdaten = stammdaten
        self.dataFlow = dataFlow
        self.actorUserID = actorUserID
        self.userID = userID
        self.clockodoUserID = clockodoUserID
    }

    public func ladeClockodoStammdaten() async {
        do {
            async let k = stammdaten.listeKunden()
            async let p = stammdaten.listeProjekte()
            async let l = stammdaten.listeLeistungen()
            kunden = try await k.filter(\.isActive).sorted { $0.name < $1.name }
            projekte = try await p.filter(\.isActive).sorted { $0.name < $1.name }
            leistungen = try await l.filter(\.isActive).sorted { $0.name < $1.name }
            stammdatenFehler = nil
        } catch {
            stammdatenFehler = error.localizedDescription
        }
    }

    public func ladeGebuchteEintraege(jetzt: Date = Date()) async {
        let (seit, bis) = zeitraum.spanne(jetzt: jetzt)
        do {
            gebuchteEintraege = try await stammdaten.entries(seit: seit, bis: bis, userID: clockodoUserID)
                .sorted { $0.start > $1.start }
        } catch {
            stammdatenFehler = error.localizedDescription
        }
    }

    public func loescheEintrag(_ entry: ClockodoEintrag) async {
        zustandJeEintrag[entry.id] = .saving
        do {
            try await booking.loescheEintrag(id: entry.id, nutzerHatJetztBestaetigt: true)
            gebuchteEintraege.removeAll { $0.id == entry.id }
            zustandJeEintrag[entry.id] = nil
            dataFlow?.log(
                integrationID: "CLOCKODO_ZEITTABELLE_BUCHUNG", actorUserID: actorUserID,
                action: .success, recordsWritten: 1,
                summary: "Zeit-Tabelle: Eintrag \(entry.id) gelöscht")
        } catch {
            zustandJeEintrag[entry.id] = .failed(error.localizedDescription)
            dataFlow?.log(
                integrationID: "CLOCKODO_ZEITTABELLE_BUCHUNG", actorUserID: actorUserID,
                action: .error, errorMessage: error.localizedDescription,
                summary: "Zeit-Tabelle: Löschen von Eintrag \(entry.id) fehlgeschlagen")
        }
    }

    public func label(fuer entry: ClockodoEintrag) -> (kunde: String, leistung: String) {
        let kunde = kunden.first { $0.id == entry.kundeID }?.name ?? "Kunde \(entry.kundeID)"
        let leistung = leistungen.first { $0.id == entry.leistungID }?.name ?? "Leistung \(entry.leistungID)"
        return (kunde, leistung)
    }

    public func projekte(fuerKunde kundeID: Int?) -> [ClockodoProjekt] {
        guard let kundeID else { return [] }
        return projekte.filter { $0.kundeID == kundeID }
    }

    private var effectiveUserID: String {
        let t = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? CurrentUserContext.timerFallbackID : t
    }

    public func laden() throws {
        let uid = effectiveUserID
        let records = try db.read { try ClockodoEchteBuchungRecord.filter(Column("userID") == uid).fetchAll($0) }
        gebuchteIDs = Set(records.compactMap { UUID(uuidString: $0.zeilenID) })
    }

    public func rowItems(ausSegmenten segmente: [TimeSegment]) -> [ClockodoZeitZeile] {
        (ClockodoZeitZeile.timerRows(ausSegmenten: segmente) + manuelleZeilen)
            .sorted { $0.startedAt > $1.startedAt }
    }

    public func fuegeManuelleZeileHinzu() {
        manuelleZeilen.append(ClockodoZeitZeile())
    }

    public func entferneManuelleZeile(_ id: UUID) {
        manuelleZeilen.removeAll { $0.id == id }
    }

    public func istGebucht(_ id: UUID) -> Bool { gebuchteIDs.contains(id) }

    public func buchen(_ rowItem: ClockodoZeitZeile, projects: [Project], customers: [Customer]) async {
        guard istGebucht(rowItem.id) == false else { return }
        guard rowItem.endedAt > rowItem.startedAt else {
            zustandJeZeile[rowItem.id] = .failed("Ende muss nach Start liegen.")
            return
        }

        let customersID: Int
        let servicesID: Int
        let projectsID: Int?

        switch rowItem.herkunft {
        case .timer:
            switch ClockodoBookingResolver.resolve(
                projectNumber: rowItem.projectNumber, kostenstelle: rowItem.kostenstelle, projects: projects, customers: customers
            ) {
            case .success(let r):
                customersID = r.customersID
                servicesID = r.servicesID
                projectsID = nil
            case .failure(let reason):
                zustandJeZeile[rowItem.id] = .failed(reason.beschreibung)
                return
            }
        case .manuell:
            guard let kundeID = rowItem.clockodoKundeID, let leistungID = rowItem.clockodoLeistungID else {
                zustandJeZeile[rowItem.id] = .failed("Kunde und Leistung müssen ausgewählt sein.")
                return
            }
            customersID = kundeID
            servicesID = leistungID
            projectsID = rowItem.clockodoProjektID
        }

        zustandJeZeile[rowItem.id] = .saving
        do {
            let entryID = try await booking.createEntry(
                customersID: customersID, servicesID: servicesID, projectsID: projectsID,
                timeSince: rowItem.startedAt, timeUntil: rowItem.endedAt,
                billable: rowItem.billable, text: rowItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : rowItem.text,
                nutzerHatJetztBestaetigt: true)
            try markiereGebucht(rowItem.id, entryID: entryID)
            zustandJeZeile[rowItem.id] = .saved(Date())
            dataFlow?.log(
                integrationID: "CLOCKODO_ZEITTABELLE_BUCHUNG", actorUserID: actorUserID,
                action: .success, recordsWritten: 1,
                summary: "Zeit-Tabelle: Zeile gebucht (Entry \(entryID))")
        } catch {
            zustandJeZeile[rowItem.id] = .failed(error.localizedDescription)
            dataFlow?.log(
                integrationID: "CLOCKODO_ZEITTABELLE_BUCHUNG", actorUserID: actorUserID,
                action: .error, errorMessage: error.localizedDescription,
                summary: "Zeit-Tabelle: Buchung fehlgeschlagen")
        }
    }

    public func bearbeiteText(_ entry: ClockodoEintrag, text: String) async {
        let neuerText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        zustandJeEintrag[entry.id] = .saving
        do {
            try await booking.aktualisiereEintragText(id: entry.id, text: neuerText, nutzerHatJetztBestaetigt: true)
            if let i = gebuchteEintraege.firstIndex(where: { $0.id == entry.id }) {
                let e = gebuchteEintraege[i]
                gebuchteEintraege[i] = ClockodoEintrag(
                    id: e.id, kundeID: e.kundeID, projektID: e.projektID, leistungID: e.leistungID,
                    text: neuerText.isEmpty ? nil : neuerText, start: e.start, dauerSekunden: e.dauerSekunden,
                    billable: e.billable)
            }
            zustandJeEintrag[entry.id] = nil
            dataFlow?.log(
                integrationID: "CLOCKODO_ZEITTABELLE_BUCHUNG", actorUserID: actorUserID,
                action: .success, recordsWritten: 1, summary: "Zeit-Tabelle: Text von Eintrag \(entry.id) geändert")
        } catch {
            zustandJeEintrag[entry.id] = .failed(error.localizedDescription)
            dataFlow?.log(
                integrationID: "CLOCKODO_ZEITTABELLE_BUCHUNG", actorUserID: actorUserID,
                action: .error, errorMessage: error.localizedDescription,
                summary: "Zeit-Tabelle: Textänderung an Eintrag \(entry.id) fehlgeschlagen")
        }
    }

    public func setzeBillable(_ entry: ClockodoEintrag, billable: Bool) async {
        zustandJeEintrag[entry.id] = .saving
        do {
            try await booking.setzeBillable(id: entry.id, billable: billable, nutzerHatJetztBestaetigt: true)
            if let i = gebuchteEintraege.firstIndex(where: { $0.id == entry.id }) {
                let e = gebuchteEintraege[i]
                gebuchteEintraege[i] = ClockodoEintrag(
                    id: e.id, kundeID: e.kundeID, projektID: e.projektID, leistungID: e.leistungID,
                    text: e.text, start: e.start, dauerSekunden: e.dauerSekunden, billable: billable)
            }
            zustandJeEintrag[entry.id] = nil
            dataFlow?.log(
                integrationID: "CLOCKODO_ZEITTABELLE_BUCHUNG", actorUserID: actorUserID,
                action: .success, recordsWritten: 1,
                summary: "Zeit-Tabelle: Eintrag \(entry.id) abrechenbar=\(billable)")
        } catch {
            zustandJeEintrag[entry.id] = .failed(error.localizedDescription)
        }
    }

    private func markiereGebucht(_ id: UUID, entryID: String) throws {
        gebuchteIDs.insert(id)
        let record = ClockodoEchteBuchungRecord(
            zeilenID: id.uuidString, clockodoEntryID: entryID,
            gebuchtAm: Date().timeIntervalSince1970, userID: effectiveUserID)
        try db.write { try record.insert($0) }
    }
}
