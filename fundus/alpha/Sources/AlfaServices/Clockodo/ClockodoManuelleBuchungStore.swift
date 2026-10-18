import Foundation
import AlfaKit

@MainActor
@Observable
public final class ClockodoManuelleBuchungStore {
    public var projectNumber: String = ""
    public var kostenstelle: String = ""
    public var date: Date = Date()
    public var startUhrzeit: Date = Date()
    public var endeUhrzeit: Date = Date()
    public var billable: Bool = true
    public var text: String = ""

    public private(set) var saveState: SaveState = .idle
    public private(set) var gebuchteEntryID: String?

    private let booking: ClockodoBooking
    private let dataFlow: DataFlowLogger?
    private let actorUserID: String

    public init(
        booking: ClockodoBooking = ClockodoClient(),
        dataFlow: DataFlowLogger? = nil,
        actorUserID: String = ""
    ) {
        self.booking = booking
        self.dataFlow = dataFlow
        self.actorUserID = actorUserID
    }

    public nonisolated static func buchbareKostenstellen(aus leistungen: [Kostenstelle] = Kostenstelle.defaults) -> [Kostenstelle] {
        leistungen.filter { $0.clockodoServiceID != nil }
    }

    public nonisolated static func kombiniereZeitraum(
        date: Date, startUhrzeit: Date, endeUhrzeit: Date, calendar: Calendar = .current
    ) -> (start: Date, ende: Date)? {
        let tagKomponenten = calendar.dateComponents([.year, .month, .day], from: date)
        guard let tag = calendar.date(from: tagKomponenten) else { return nil }
        let startKomponenten = calendar.dateComponents([.hour, .minute], from: startUhrzeit)
        let endeKomponenten = calendar.dateComponents([.hour, .minute], from: endeUhrzeit)
        guard
            let start = calendar.date(bySettingHour: startKomponenten.hour ?? 0, minute: startKomponenten.minute ?? 0, second: 0, of: tag),
            let ende = calendar.date(bySettingHour: endeKomponenten.hour ?? 0, minute: endeKomponenten.minute ?? 0, second: 0, of: tag)
        else { return nil }
        return (start, ende)
    }

    public func buchen(projects: [Project], customers: [Customer]) async {
        gebuchteEntryID = nil
        guard let zeitraum = Self.kombiniereZeitraum(date: date, startUhrzeit: startUhrzeit, endeUhrzeit: endeUhrzeit),
              zeitraum.ende > zeitraum.start
        else {
            saveState = .failed("Ende muss nach Start liegen.")
            return
        }
        let resolution: ClockodoBookingResolution
        switch ClockodoBookingResolver.resolve(projectNumber: projectNumber, kostenstelle: kostenstelle, projects: projects, customers: customers) {
        case .success(let r):
            resolution = r
        case .failure(let reason):
            saveState = .failed(reason.beschreibung)
            return
        }

        saveState = .saving
        do {
            let id = try await booking.createEntry(
                customersID: resolution.customersID, servicesID: resolution.servicesID, projectsID: nil,
                timeSince: zeitraum.start, timeUntil: zeitraum.ende,
                billable: billable, text: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text,
                nutzerHatJetztBestaetigt: true)
            gebuchteEntryID = id
            saveState = .saved(Date())
            dataFlow?.log(
                integrationID: "CLOCKODO_MANUELLE_BUCHUNG", actorUserID: actorUserID,
                action: .success, recordsWritten: 1,
                summary: "Zeit manuell an Clockodo gebucht (Projekt \(projectNumber), Entry \(id))")
        } catch {
            saveState = .failed(error.localizedDescription)
            dataFlow?.log(
                integrationID: "CLOCKODO_MANUELLE_BUCHUNG", actorUserID: actorUserID,
                action: .error, errorMessage: error.localizedDescription,
                summary: "Manuelle Clockodo-Buchung fehlgeschlagen (Projekt \(projectNumber))")
        }
    }

    public func zuruecksetzenNachErfolg() {
        text = ""
        saveState = .idle
        gebuchteEntryID = nil
    }
}
