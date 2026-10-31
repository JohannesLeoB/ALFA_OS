import Foundation

struct TenantFinding: Sendable, Equatable {
    struct Template: Sendable, Equatable {
        let orderID: String
        let orderNumber: String?
        let contactID: String?
        let contactPersonID: String?
        let addressCountryID: String?
        let taxRuleID: String?
        let taxRate: Double?
        let taxType: String?
        let currency: String?

        init(
            orderID: String, orderNumber: String? = nil, contactID: String? = nil, contactPersonID: String? = nil,
            addressCountryID: String? = nil, taxRuleID: String? = nil, taxRate: Double? = nil,
            taxType: String? = nil, currency: String? = nil
        ) {
            self.orderID = orderID
            self.orderNumber = orderNumber
            self.contactID = contactID
            self.contactPersonID = contactPersonID
            self.addressCountryID = addressCountryID
            self.taxRuleID = taxRuleID
            self.taxRate = taxRate
            self.taxType = taxType
            self.currency = currency
        }
    }

    struct Unit: Sendable, Equatable, Identifiable {
        let id: String
        let name: String

        init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    enum Gap: Sendable, Equatable {
        case versionUnreadable
        case noOfferForNumber
        case noOffer
        case contactPersonMissing
        case addressCountryMissing
        case taxRateMissing
        case unitsMissing
        case positionTaxRateMissing
        case taxRateMismatch(header: Double, positions: Double)
        case nextNumberUnavailable

        var key: String {
            switch self {
            case .versionUnreadable: "sevdesk.gap.versionUnreadable"
            case .noOfferForNumber: "sevdesk.gap.noOfferForNumber"
            case .noOffer: "sevdesk.gap.noOffer"
            case .contactPersonMissing: "sevdesk.gap.contactPersonMissing"
            case .addressCountryMissing: "sevdesk.gap.addressCountryMissing"
            case .taxRateMissing: "sevdesk.gap.taxRateMissing"
            case .unitsMissing: "sevdesk.gap.unitsMissing"
            case .positionTaxRateMissing: "sevdesk.gap.positionTaxRateMissing"
            case .taxRateMismatch: "sevdesk.gap.taxRateMismatch"
            case .nextNumberUnavailable: "sevdesk.gap.nextNumberUnavailable"
            }
        }

        var arguments: [String] {
            if case .taxRateMismatch(let header, let positions) = self { return [String(header), String(positions)] }
            return []
        }
    }

    let version: String?
    let template: Template?
    let units: [Unit]
    let positionTaxRate: Double?
    let nextNumber: String?
    let gaps: [Gap]

    init(
        version: String? = nil, template: Template? = nil, units: [Unit] = [], positionTaxRate: Double? = nil,
        nextNumber: String? = nil, gaps: [Gap] = []
    ) {
        self.version = version
        self.template = template
        self.units = units
        self.positionTaxRate = positionTaxRate
        self.nextNumber = nextNumber
        self.gaps = gaps
    }
}

public struct Contact: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var customerNumber: String?

    public init(id: String, name: String, customerNumber: String? = nil) {
        self.id = id
        self.name = name
        self.customerNumber = customerNumber
    }
}

enum ContactMatch: Equatable, Sendable {
    case unique(id: String, name: String?)
    case none
    case ambiguous([Candidate])
    case contactPersonOnly(Candidate)

    struct Candidate: Equatable, Sendable, Identifiable {
        let id: String
        let name: String?
        let isContactPerson: Bool

        init(id: String, name: String?, isContactPerson: Bool = false) {
            self.id = id
            self.name = name
            self.isContactPerson = isContactPerson
        }
    }
}

struct Order: Identifiable, Equatable, Sendable {
    var id: String
    var orderNumber: String?
    var orderType: String
    var rawStatus: String
    var sumNet: Double
    var sumTax: Double
    var sumGross: Double
    var contactID: String?
    var customerInternalNote: String?
    var header: String?

    init(
        id: String, orderNumber: String? = nil, orderType: String, rawStatus: String,
        sumNet: Double = 0, sumTax: Double = 0, sumGross: Double = 0, contactID: String? = nil,
        customerInternalNote: String? = nil, header: String? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.orderType = orderType
        self.rawStatus = rawStatus
        self.sumNet = sumNet
        self.sumTax = sumTax
        self.sumGross = sumGross
        self.contactID = contactID
        self.customerInternalNote = customerInternalNote
        self.header = header
    }
}

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

enum SevdeskFailure: Error, Equatable, Sendable {
    case notConnected
    case invalidResponse
    case http(Int)
    case decoding

    var detail: String {
        switch self {
        case .notConnected: "notConnected"
        case .invalidResponse: "invalidResponse"
        case .http(let code): "http \(code)"
        case .decoding: "decoding"
        }
    }
}
