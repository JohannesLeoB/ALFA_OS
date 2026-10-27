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
