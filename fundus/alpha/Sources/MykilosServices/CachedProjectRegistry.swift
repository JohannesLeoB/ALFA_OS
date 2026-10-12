import Foundation
import MykilosKit

public struct CachedProjectRegistry: ProjectRegistry {
    private let customers: FileBackedRepository<Customer>
    private let projects: FileBackedRepository<Project>

    public init(directory: URL? = nil) throws {
        let target = directory ?? DatenRoot.root()
        self.customers = try FileBackedRepository<Customer>(filename: "customers", directory: target)
        self.projects = try FileBackedRepository<Project>(filename: "projects", directory: target)
    }

    public func allCustomers() throws -> [Customer] { try customers.loadAll() }
    public func allProjects() throws -> [Project] { try projects.loadAll() }

    public func projects(forCustomer customerNumber: String) throws -> [Project] {
        try projects.loadAll().filter { $0.customerNumber == customerNumber }
    }

    public func addenda(ofParent projectNumber: String) throws -> [Project] {
        try projects.loadAll().filter { $0.parentProjectNumber == projectNumber }
    }

    public func replaceCustomers(_ list: [Customer]) throws { try customers.saveAll(list) }
    public func replaceProjects(_ list: [Project]) throws { try projects.saveAll(list) }

    public func clearCache() throws {
        try customers.saveAll([])
        try projects.saveAll([])
    }
}
