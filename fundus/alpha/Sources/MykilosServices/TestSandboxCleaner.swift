import Foundation
import MykilosKit

public struct TestSandboxCleanupCandidate: Sendable, Equatable {
    public let baseID: String
    public let table: String
    public let recordID: String
    public let name: String?
    public let source: String?

    public init(baseID: String, table: String, recordID: String, name: String?, source: String?) {
        self.baseID = baseID; self.table = table; self.recordID = recordID
        self.name = name; self.source = source
    }
}

public struct TestSandboxSkip: Sendable, Equatable {
    public let candidate: TestSandboxCleanupCandidate
    public let reason: String
}

public struct TestSandboxCleanupReport: Sendable, Equatable {
    public let deleted: [TestSandboxCleanupCandidate]
    public let skipped: [TestSandboxSkip]
}

public struct TestSandboxCleaner: Sendable {
    private let fetcher: AirtableFetching
    private let deleter: AirtableRecordDeleting
    private let deletableMap: [String: Set<String>]

    public init(
        fetcher: AirtableFetching, deleter: AirtableRecordDeleting,
        deletableMap: [String: Set<String>] = AirtableClient.testDeletableMap
    ) {
        self.fetcher = fetcher
        self.deleter = deleter
        self.deletableMap = deletableMap
    }

    private func isDeletable(baseID: String, table: String) -> Bool {
        deletableMap[baseID]?.contains(table) == true
    }

    public func findTestArtifacts(
        baseID: String, table: String, nameField: String, quelleField: String = "Quelle"
    ) async throws -> [TestSandboxCleanupCandidate] {
        let records = try await fetcher.fetchRecords(baseID: baseID, table: table)
        return records.compactMap { fields -> TestSandboxCleanupCandidate? in
            let name = fields[nameField]?.stringValue
            let source = fields[quelleField]?.stringValue
            guard TestMarker.isTestRecord(name: name, source: source) else { return nil }
            guard let recordID = fields["_airtableRecordID"]?.stringValue, !recordID.isEmpty else { return nil }
            return TestSandboxCleanupCandidate(
                baseID: baseID, table: table, recordID: recordID, name: name, source: source)
        }
    }

    public func cleanup(
        _ candidates: [TestSandboxCleanupCandidate], nameField: String, quelleField: String = "Quelle"
    ) async throws -> TestSandboxCleanupReport {
        var deleted: [TestSandboxCleanupCandidate] = []
        var skipped: [TestSandboxSkip] = []

        for candidate in candidates {
            guard isDeletable(baseID: candidate.baseID, table: candidate.table) else {
                skipped.append(TestSandboxSkip(candidate: candidate, reason: "nicht auf TEST-Delete-Whitelist"))
                continue
            }
            let freshRecords = try await fetcher.fetchRecords(baseID: candidate.baseID, table: candidate.table)
            guard let fresh = freshRecords.first(where: { $0["_airtableRecordID"]?.stringValue == candidate.recordID }) else {
                skipped.append(TestSandboxSkip(candidate: candidate, reason: "Record nicht mehr vorhanden"))
                continue
            }
            guard TestMarker.isTestRecord(name: fresh[nameField]?.stringValue, source: fresh[quelleField]?.stringValue) else {
                skipped.append(TestSandboxSkip(candidate: candidate, reason: "Re-Fetch bestätigt TEST-Marker nicht mehr — NICHT gelöscht"))
                continue
            }
            try await deleter.deleteRecord(baseID: candidate.baseID, table: candidate.table, recordID: candidate.recordID)
            deleted.append(candidate)
        }
        return TestSandboxCleanupReport(deleted: deleted, skipped: skipped)
    }
}
