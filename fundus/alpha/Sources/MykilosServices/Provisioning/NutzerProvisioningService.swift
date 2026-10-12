import Foundation
import Observation
import MykilosKit

@MainActor
@Observable
public final class NutzerProvisioningService {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.clockodo_users")

    public static let tabelle = "Clockodo-Nutzer"

    public private(set) var saveState: SaveState = .idle

    private let airtableFetch: any AirtableFetching
    private let airtableCreate: any AirtableRecordCreating

    private let isWritable: (String, String) -> Bool

    public init(
        airtableFetch: any AirtableFetching,
        airtableCreate: any AirtableRecordCreating,
        isWritable: @escaping (String, String) -> Bool = AirtableClient.isWritable
    ) {
        self.airtableFetch = airtableFetch
        self.airtableCreate = airtableCreate
        self.isWritable = isWritable
    }

    @discardableResult
    public func findOrCreate(googleEmail: String, displayName: String) async throws -> String {
        guard isWritable(Self.baseID, Self.tabelle) else {
            throw ProvisioningError.schrittFehlgeschlagen(
                .airtableRecord,
                "Tabelle \(Self.tabelle)@\(Self.baseID) ist nicht schreibbar — "
                + "zuerst von der Administration auf die Airtable-Schreib-Freigabeliste setzen lassen.")
        }

        saveState = .saving
        do {
            if let bestehendeID = try await findeBestehendenRecord(email: googleEmail) {
                saveState = .saved(Date())
                return bestehendeID
            }

            let felder: [String: AirtableFieldValue] = [
                "Name": .string(displayName),
                "E-Mail": .string(googleEmail),
                "Aktiv": .string("true")
            ]
            let recordID = try await airtableCreate.createRecord(baseID: Self.baseID, table: Self.tabelle, fields: felder)
            saveState = .saved(Date())
            return recordID
        } catch {
            saveState = .failed(String(describing: error))
            throw error
        }
    }

    private func findeBestehendenRecord(email: String) async throws -> String? {
        let needle = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let records = try await airtableFetch.fetchRecords(baseID: Self.baseID, table: Self.tabelle)
        let match = records.first { fields in
            let rowEmail = (fields["E-Mail"]?.stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return rowEmail.isEmpty == false && rowEmail == needle
        }
        return match?["_airtableRecordID"]?.stringValue
    }
}
