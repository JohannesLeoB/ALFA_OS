import Foundation

public struct Receipt: Sendable, Equatable, Codable, Identifiable {
    public var id: String { orderID }

    let orderID: String
    let kind: String
    let number: String
    let projectNumber: String
    let customerNumber: String?
    let customerName: String?
    let contactID: String
    let createdAt: Date
    var lastStatus: Int
    var lastUpdate: String?
    var pdfStored: Bool

    init(
        orderID: String, kind: String = "AN", number: String, projectNumber: String, customerNumber: String?,
        customerName: String?, contactID: String, createdAt: Date, lastStatus: Int = 100, lastUpdate: String? = nil,
        pdfStored: Bool = false
    ) {
        self.orderID = orderID
        self.kind = kind
        self.number = number
        self.projectNumber = projectNumber
        self.customerNumber = customerNumber
        self.customerName = customerName
        self.contactID = contactID
        self.createdAt = createdAt
        self.lastStatus = lastStatus
        self.lastUpdate = lastUpdate
        self.pdfStored = pdfStored
    }
}
