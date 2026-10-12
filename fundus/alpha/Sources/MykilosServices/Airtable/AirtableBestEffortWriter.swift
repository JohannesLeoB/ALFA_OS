import Foundation

public enum AirtableWriteOutcome: Sendable, Equatable {
    case schlafend
    case geschrieben(recordID: String)
    case nichtVerbunden
    case error(String)
}

public struct AirtableBestEffortWriter: Sendable {
    private let creator: any AirtableRecordCreating

    public init(creator: any AirtableRecordCreating) {
        self.creator = creator
    }

    public func schreibe(baseID: String, table: String, felder: [String: AirtableFieldValue]) async -> AirtableWriteOutcome {
        do {
            let recordID = try await creator.createRecord(baseID: baseID, table: table, fields: felder)
            return .geschrieben(recordID: recordID)
        } catch AirtableError.invalidBaseID {
            return .schlafend
        } catch AirtableError.notConnected {
            return .nichtVerbunden
        } catch {
            return .error(String(describing: error))
        }
    }
}
