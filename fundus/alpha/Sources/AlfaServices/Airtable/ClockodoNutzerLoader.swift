import Foundation
import AlfaKit

@MainActor
@Observable
public final class ClockodoNutzerLoader {
    public enum LoadState: Equatable {
        case idle
        case loading
        case content(ResidentIdentityHandles)
        case empty
        case notConnected
        case error(String)
    }

    public private(set) var state: LoadState = .idle

    public var handles: ResidentIdentityHandles? {
        if case .content(let h) = state { return h }
        return nil
    }

    private let baseID: String
    private let tableID: String
    private let client: AirtableFetching

    public init(

        baseID: String = CompanySetup.valueOrEmpty("airtable.base.clockodo_users"),
        tableID: String = CompanySetup.valueOrEmpty("airtable.table.clockodo_users"),
        client: AirtableFetching = AirtableClient()
    ) {
        self.baseID = baseID
        self.tableID = tableID
        self.client = client
    }

    public func load(matchingEmail email: String) async {
        state = .loading
        do {
            let records = try await client.fetchRecords(baseID: baseID, table: tableID)
            if let handles = AirtableClient.mapResidentIdentity(from: records, matchingEmail: email) {
                state = .content(handles)
            } else {
                state = .empty
            }
        } catch AirtableError.notConnected {
            state = .notConnected
        } catch AirtableError.httpError(let code) {
            state = .error("HTTP \(code)")
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
