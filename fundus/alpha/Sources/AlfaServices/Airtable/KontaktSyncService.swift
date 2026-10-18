import Foundation
import AlfaKit

public struct KontaktSyncKonfiguration: Sendable, Equatable {
    public let baseID: String
    public let kundenGoldenTable: String
    public let lieferantenTable: String
    public let weitereKontakteTable: String

    public init(baseID: String, kundenGoldenTable: String,
                lieferantenTable: String, weitereKontakteTable: String) {
        self.baseID = baseID
        self.kundenGoldenTable = kundenGoldenTable
        self.lieferantenTable = lieferantenTable
        self.weitereKontakteTable = weitereKontakteTable
    }

    public static let live = KontaktSyncKonfiguration(
        baseID: CompanySetup.valueOrEmpty("airtable.base.golden_customers"),
        kundenGoldenTable: CompanySetup.valueOrEmpty("airtable.table.golden_customers"),
        lieferantenTable: CompanySetup.valueOrEmpty("airtable.table.suppliers"),
        weitereKontakteTable: CompanySetup.valueOrEmpty("airtable.table.contacts"))
}

@MainActor
@Observable
public final class KontaktSyncService {
    public enum SyncState: Equatable {
        case idle
        case syncing
        case synced(Int)
        case notConnected
        case error(String)
    }

    public private(set) var state: SyncState = .idle

    private let store: KontaktStore
    private let fetcher: AirtableFetching
    private let konfiguration: KontaktSyncKonfiguration

    public init(store: KontaktStore,
                fetcher: AirtableFetching = AirtableClient(),
                konfiguration: KontaktSyncKonfiguration = .live) {
        self.store = store
        self.fetcher = fetcher
        self.konfiguration = konfiguration
    }

    @discardableResult
    public func synchronisiere(jetzt: Double = Date().timeIntervalSince1970) async -> SyncState {
        state = .syncing
        do {
            let golden  = try await fetch(konfiguration.kundenGoldenTable)
            let liefer  = try await fetch(konfiguration.lieferantenTable)
            let weitere = try await fetch(konfiguration.weitereKontakteTable)

            let vereint = KontaktQuellenMapper.vereinigeAlle(
                kundenGolden: golden, lieferanten: liefer, weitereKontakte: weitere)

            try await store.ersetzeAirtableStand(vereint, jetzt: jetzt)
            let total = try await store.alle().count
            state = .synced(total)
        } catch AirtableError.notConnected {
            state = .notConnected
        } catch let AirtableError.httpError(code) {
            state = .error("HTTP \(code)")
        } catch {
            state = .error(error.localizedDescription)
        }
        return state
    }

    private func fetch(_ table: String) async throws -> [[String: AirtableFieldValue]] {
        guard !table.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await fetcher.fetchRecords(baseID: konfiguration.baseID, table: table)
    }
}
