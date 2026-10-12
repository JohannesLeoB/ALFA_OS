import Foundation
import MykilosKit

public enum MediathekStagingPort {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.media_library")
    public static let stagingTabelle = CompanySetup.valueOrEmpty("airtable.table.media_staging")
    public static let integrationID = "MEDIATHEK_STAGING_UPLOAD"

    public struct Entry: Sendable, Equatable {
        public let name: String
        public let dateiendung: String

        public let drivePfad: String
        public let groesseMB: Double?

        public let categoryFolder: String

        public let hersteller: String

        public init(name: String, dateiendung: String, drivePfad: String,
                    groesseMB: Double?, categoryFolder: String, hersteller: String) {
            self.name = name
            self.dateiendung = dateiendung
            self.drivePfad = drivePfad
            self.groesseMB = groesseMB
            self.categoryFolder = categoryFolder
            self.hersteller = hersteller
        }
    }

    @discardableResult
    public static func schreibeUpload(
        _ entry: Entry,
        client: AirtableRecordCreating = AirtableClient(),
        logger: DataFlowLogger? = nil,
        actorUserID: String = "unbekannt"
    ) async throws -> String {
        var fields: [String: AirtableFieldValue] = [
            "Name": .string(entry.name),
            "Dateityp": .string("Bild"),
            "Dateiendung": .string(entry.dateiendung.lowercased()),
            "Drive-Pfad": .string(entry.drivePfad),
            "Kategorie": .string(entry.categoryFolder),
            "Hersteller": .string(entry.hersteller),
            "Erkennungsquelle": .string("Human bestätigt"),

            "Review-Status": .string("Freigegeben")
        ]
        if let mb = entry.groesseMB {
            fields["Größe MB"] = .number((mb * 100).rounded() / 100)
        }
        do {
            let recordID = try await client.createRecord(
                baseID: baseID, table: stagingTabelle, fields: fields)
            await MainActor.run {
                logger?.log(integrationID: integrationID, actorUserID: actorUserID,
                            action: .success, recordsWritten: 1,
                            summary: "Mediathek-Staging: \(entry.name).\(entry.dateiendung) → \(entry.categoryFolder)/\(entry.hersteller)")
            }
            return recordID
        } catch {
            await MainActor.run {
                logger?.log(integrationID: integrationID, actorUserID: actorUserID,
                            action: .error, errorMessage: String(describing: error),
                            summary: "Mediathek-Staging FEHLER: \(entry.name).\(entry.dateiendung)")
            }
            throw error
        }
    }
}
