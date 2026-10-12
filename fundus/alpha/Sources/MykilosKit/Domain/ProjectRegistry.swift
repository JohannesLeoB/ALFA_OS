import Foundation

public protocol ProjectRegistry: Sendable {
    func allCustomers() throws -> [Customer]
    func allProjects() throws -> [Project]
    func projects(forCustomer customerNumber: String) throws -> [Project]
    func addenda(ofParent projectNumber: String) throws -> [Project]
}

public struct ProjectClickUpRef: Sendable, Equatable {
    public let projectNumber: String
    public let title: String
    public let listID: String

    public init(projectNumber: String, title: String, listID: String) {
        self.projectNumber = projectNumber
        self.title = title
        self.listID = listID
    }
}
