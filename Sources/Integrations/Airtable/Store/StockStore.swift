import Assistant
import Core

public actor StockStore: StockPort {
    static let tableName = "Lagerliste"

    private let loader: RecordListStore<StockItem>
    private var items: [StockItem] = []

    public init(fetch: any RecordFetchPort,
                baseID: String = CompanyValues.valueOrEmpty("airtable.base.article_catalog"),
                table: String? = nil) {
        loader = RecordListStore(fetch: fetch, baseID: baseID, table: table ?? Self.tableName, map: StockEngine.items(from:))
    }

    public func current() async -> StockListState {
        if items.isEmpty == false { return .items(items) }
        do {
            let loaded = try await loader.load()
            guard loaded.isEmpty == false else { return .empty }
            items = loaded
            return .items(loaded)
        } catch AirtableFailure.notConnected {
            return .notConnected
        } catch let failure as AirtableFailure {
            return .failed(failure.detail)
        } catch {
            return .failed(String(describing: error))
        }
    }

    func reload() {
        items = []
    }
}

struct RecordListStore<Item: Sendable>: Sendable {
    let fetch: any RecordFetchPort
    let baseID: String
    let table: String
    let map: @Sendable ([Record]) -> [Item]

    func load() async throws -> [Item] {
        map(try await fetch.fetchRecords(baseID: baseID, table: table))
    }
}
