import Foundation
import MykilosKalkulationsCore
import MykilosKit

public struct SchaetzmodellSchreiber: Sendable {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.estimation_model")
    public static let tableID = CompanySetup.valueOrEmpty("airtable.table.estimation_model")

    static let feldSchluessel = "Schlüssel"
    static let fieldValue = "Wert"

    private let fetch: AirtableFetching
    private let update: AirtableRecordUpdating

    public init(fetch: AirtableFetching = AirtableClient(), update: AirtableRecordUpdating = AirtableClient()) {
        self.fetch = fetch
        self.update = update
    }

    public static var istWach: Bool {
        AirtableClient.isWritable(baseID: baseID, table: tableID)
    }

    static func findeRecordID(key: String, records: [[String: AirtableFieldValue]]) -> (recordID: String, alterWert: Double)? {
        for fields in records {
            guard fields[feldSchluessel]?.anyStringValue == key,
                  let recordID = fields["_airtableRecordID"]?.stringValue else { continue }
            let alterWert = fields[fieldValue]?.numberValue ?? 0
            return (recordID, alterWert)
        }
        return nil
    }

    public func schreibeWert(key: String, neuerWert: Double) async -> SchaetzmodellSchreibErgebnis {
        let records: [[String: AirtableFieldValue]]
        do {
            records = try await fetch.fetchRecords(baseID: Self.baseID, table: Self.tableID)
        } catch {
            return .error("Schätzmodell-Tabelle nicht lesbar: \(error)")
        }
        guard let match = Self.findeRecordID(key: key, records: records) else {
            return .schluesselNichtGefunden
        }
        do {
            try await update.updateRecord(
                baseID: Self.baseID, table: Self.tableID, recordID: match.recordID,
                fields: [Self.fieldValue: .number(neuerWert)])
            return .geschrieben(alterWert: match.alterWert)
        } catch let error as AirtableError {
            if case .invalidBaseID = error { return .schlaeft }
            return .error(String(describing: error))
        } catch {
            return .error(String(describing: error))
        }
    }
}

public enum SchaetzmodellSchreibErgebnis: Sendable, Equatable {
    case geschrieben(alterWert: Double)
    case schlaeft
    case schluesselNichtGefunden
    case error(String)
}
