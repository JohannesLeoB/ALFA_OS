import Foundation
import MykilosKit

public struct AirtableRegistry {
    private let client: AirtableFetching
    public let customersTable: String
    public let projectsTable: String

    public init(
        client: AirtableFetching = AirtableClient(),
        customersTable: String = "Kunden",
        projectsTable: String = "Projekte"
    ) {
        self.client = client
        self.customersTable = customersTable
        self.projectsTable = projectsTable
    }

    public func sync(baseID: String, customersBaseID: String? = nil, into cache: CachedProjectRegistry) async throws {
        let customerRecords = try await client.fetchRecords(baseID: customersBaseID ?? baseID, table: customersTable)
        let projectRecords = try await client.fetchRecords(baseID: baseID, table: projectsTable)

        let customers = AirtableClient.mapCustomers(from: customerRecords)
        let projects = AirtableClient.mapProjects(from: projectRecords)

        try cache.replaceCustomers(customers)
        try cache.replaceProjects(projects)
    }
}
