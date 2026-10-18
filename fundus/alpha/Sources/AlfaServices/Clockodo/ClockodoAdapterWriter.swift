import Foundation
import AlfaKit

public struct ClockodoAdapterWriter: Sendable {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.clockodo_bookings")
    public static let table = "Zeitbuchungen"

    static let fieldProjectNumber = CompanySetup.valueOrEmpty("airtable.field.clockodo.project_number")
    static let feldMitarbeiter   = CompanySetup.valueOrEmpty("airtable.field.clockodo.employee")
    static let feldDatum         = CompanySetup.valueOrEmpty("airtable.field.clockodo.date")
    static let feldKW            = CompanySetup.valueOrEmpty("airtable.field.clockodo.calendar_week")
    static let feldProjektTitel  = CompanySetup.valueOrEmpty("airtable.field.clockodo.project_title")
    static let feldKostenstelle  = CompanySetup.valueOrEmpty("airtable.field.clockodo.cost_center")
    static let feldDauerH        = CompanySetup.valueOrEmpty("airtable.field.clockodo.duration_hours")
    static let feldStart         = CompanySetup.valueOrEmpty("airtable.field.clockodo.start")
    static let feldEnde          = CompanySetup.valueOrEmpty("airtable.field.clockodo.end")
    static let feldStatus        = CompanySetup.valueOrEmpty("airtable.field.clockodo.status")
    static let fieldSource        = CompanySetup.valueOrEmpty("airtable.field.clockodo.source")

    private let creator: AirtableRecordCreating

    public init(creator: AirtableRecordCreating) {
        self.creator = creator
    }

    @discardableResult
    public func schreibeVorbuchung(_ segment: TimeSegment, mitarbeiter: String) async throws -> String {
        try await creator.createRecord(
            baseID: Self.baseID, table: Self.table,
            fields: Self.felder(fuer: segment, mitarbeiter: mitarbeiter))
    }

    public nonisolated static func felder(
        fuer segment: TimeSegment, mitarbeiter: String
    ) -> [String: AirtableFieldValue] {
        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let kw = isoCalendar.component(.weekOfYear, from: segment.startedAt)

        let datumFormatter = DateFormatter()
        datumFormatter.calendar = isoCalendar
        datumFormatter.timeZone = isoCalendar.timeZone
        datumFormatter.dateFormat = "yyyy-MM-dd"

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let stunden = (segment.seconds / 3600 * 100).rounded() / 100

        return [
            fieldProjectNumber: .string(segment.projectNumber),
            feldMitarbeiter: .string(mitarbeiter),
            feldDatum: .string(datumFormatter.string(from: segment.startedAt)),
            feldKW: .number(Double(kw)),
            feldProjektTitel: .string(segment.projectTitle),
            feldKostenstelle: .string(segment.kostenstelle),
            feldDauerH: .number(stunden),
            feldStart: .string(isoFormatter.string(from: segment.startedAt)),
            feldEnde: .string(isoFormatter.string(from: segment.endedAt)),
            feldStatus: .string("Vorgebucht"),
            fieldSource: .string("Timer")
        ]
    }
}
