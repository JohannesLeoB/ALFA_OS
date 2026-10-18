import Foundation
import AlfaKit

public struct TimelineItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let date: Date
    public let title: String
    public let subtitle: String?
    public let source: TimelineSource
    public let webViewLink: String?

    public let driveFile: GoogleDriveFile?

    public init(id: String, date: Date, title: String, subtitle: String?,
                source: TimelineSource, webViewLink: String?,
                driveFile: GoogleDriveFile? = nil) {
        self.id = id; self.date = date; self.title = title
        self.subtitle = subtitle; self.source = source; self.webViewLink = webViewLink
        self.driveFile = driveFile
    }
}

public enum TimelineSource: Sendable, Equatable { case drive, offer, calendar, audit, telefonnotiz }

public extension AuditEntry.Action {
    var timelineLabel: String {
        switch self {
        case .offerImported:      "Angebot importiert"
        case .draftCreated:       "Entwurf erstellt"
        case .draftSent:          "Entwurf gesendet"
        case .projectLinked:      "Projekt verknüpft"
        case .noteUpdated:        "Notiz geändert"
        case .estimateAdjusted:   "Schätzung angepasst"
        case .calibrationPromoted: "Kalibrierung übernommen"
        case .contactCreated:     "Kontakt angelegt"
        case .driveFileUploaded:  "Datei hochgeladen"
        case .warenkorbGesendet:  "Warenkorb gesendet"
        case .mailAktionAusgefuehrt: "Mail-Aktion"
        case .inviteCreated:      "Einladung erstellt"
        case .clickUpStatusChanged: "ClickUp-Status geändert"
        case .clickUpTaskCreated: "ClickUp-Aufgabe angelegt"
        case .clickUpTaskUpdated: "ClickUp-Aufgabe bearbeitet"
        case .clickUpTaskAssigned: "ClickUp-Aufgabe zugewiesen"
        case .clickUpTaskUnassigned: "ClickUp-Zuweisung entfernt"
        case .clickUpTaskDeleted: "ClickUp-Aufgabe gelöscht"
        case .clickUpDependencyAdded: "ClickUp-Abhängigkeit gesetzt"
        case .clickUpDependencyRemoved: "ClickUp-Abhängigkeit entfernt"
        case .clickUpCommentAdded: "ClickUp-Kommentar hinzugefügt"
        case .clickUpTagAdded: "ClickUp-Tag hinzugefügt"
        case .clickUpTagRemoved: "ClickUp-Tag entfernt"
        case .clickUpCustomFieldSet: "ClickUp-Custom-Field gesetzt"
        case .clickUpSubtaskCreated: "ClickUp-Subtask angelegt"
        case .clickUpTaskMoved: "ClickUp-Aufgabe verschoben"
        case .clickUpGoLiveFreigegeben: "ClickUp-Liste Go-Live freigeschaltet"
        case .clickUpGoLiveGesperrt: "ClickUp-Liste Go-Live gesperrt"
        case .clickUpTeamGoLiveFreigegeben: "Team-Mitglied Go-Live freigeschaltet"
        case .clickUpTeamGoLiveGesperrt: "Team-Mitglied Go-Live gesperrt"
        case .sevdeskGhostDraftPrepared: "sevdesk-Ghost-Entwurf simuliert"
        case .projektArchiviert:  "Projekt archiviert"
        case .projektReaktiviert: "Projekt reaktiviert"
        case .airtableFeldAusClickUpUebernommen: "ClickUp-Feldänderung übernommen"
        case .dhlLabelErstellt:   "DHL-Sendung erstellt"
        case .kalenderTerminAngelegt: "Termin angelegt"
        case .warenkorbPositionHinzugefuegt: "In den Warenkorb gelegt"
        case .dhlSendungZugestellt: "DHL-Sendung zugestellt"
        }
    }
}

public enum TimelineMerger {
    public static func merge(
        driveFiles: [GoogleDriveFile],
        offers: OffersCollector.Result,
        calendarEvents: [GoogleCalendarEvent],
        auditEntries: [AuditEntry],
        telefonnotizen: [Telefonnotiz] = []
    ) -> [TimelineItem] {
        var items: [TimelineItem] = []

        var offerFileIDs = Set<String>()
        for offer in offers.incoming + offers.outgoing {
            guard let date = offer.file.modifiedAt else { continue }
            offerFileIDs.insert(offer.file.id)
            var subtitle = offer.type.label
            if let nr = offer.belegNummer { subtitle += " · \(nr)" }
            items.append(TimelineItem(
                id: "offer:\(offer.file.id)", date: date, title: offer.file.name,
                subtitle: subtitle, source: .offer, webViewLink: offer.file.webViewLink,
                driveFile: offer.file))
        }

        for file in driveFiles {
            guard file.isFolder == false, let date = file.modifiedAt,
                  offerFileIDs.contains(file.id) == false else { continue }
            items.append(TimelineItem(
                id: "drive:\(file.id)", date: date, title: file.name,
                subtitle: file.typeLabel, source: .drive, webViewLink: file.webViewLink,
                driveFile: file))
        }

        for event in calendarEvents {
            guard let date = event.startsAt else { continue }
            items.append(TimelineItem(
                id: "cal:\(event.id)", date: date, title: event.title,
                subtitle: event.location, source: .calendar, webViewLink: nil))
        }

        for entry in auditEntries {
            items.append(TimelineItem(
                id: "audit:\(entry.id.uuidString)", date: entry.timestamp,
                title: entry.action.timelineLabel, subtitle: entry.summary,
                source: .audit, webViewLink: nil))
        }

        for notiz in telefonnotizen {
            items.append(TimelineItem(
                id: "tel:\(notiz.id)", date: notiz.date,
                title: "Telefonnotiz — \(notiz.kontakt) \(notiz.richtung.label)",
                subtitle: notiz.kurzfassung, source: .telefonnotiz, webViewLink: nil))
        }

        return items.sorted { $0.date > $1.date }
    }
}
