import Foundation

public struct ReceiptEntry: Sendable, Equatable {
    public let kind: String
    public let number: String
    public let projectNumber: String
    public let customerName: String?
    public let createdAt: Date

    public init(kind: String, number: String, projectNumber: String, customerName: String? = nil, createdAt: Date) {
        self.kind = kind
        self.number = number
        self.projectNumber = projectNumber
        self.customerName = customerName
        self.createdAt = createdAt
    }
}
