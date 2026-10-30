import Core
import Hub

public struct CustomerContactStore: ContactFeedPort {
    private let fetch: any RecordFetchPort
    private let baseID: String
    private let table: String
    private let nameField: String
    private let addressField: String

    public init(fetch: any RecordFetchPort,
                baseID: String = CompanyValues.valueOrEmpty("airtable.base.golden_customers"),
                table: String = CompanyValues.valueOrEmpty("airtable.table.golden_customers"),
                nameField: String = CompanyValues.valueOrEmpty("airtable.field.customer_name"),
                addressField: String = CompanyValues.valueOrEmpty("airtable.field.customer_email")) {
        self.fetch = fetch
        self.baseID = baseID
        self.table = table
        self.nameField = nameField
        self.addressField = addressField
    }

    public var configured: Bool { ![baseID, table, addressField].contains(where: \.isEmpty) }

    public func people() async throws -> [ContactPerson] {
        guard configured else { return [] }
        return try await fetch.fetchRecords(baseID: baseID, table: table).compactMap { record in
            guard let address = record.fields[addressField]?.anyStringValue, !address.isEmpty else { return nil }
            return ContactPerson(name: record.fields[nameField]?.anyStringValue ?? "", address: address)
        }
    }
}
