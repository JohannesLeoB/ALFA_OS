enum LabelRequestEngine {
    static let defaultProfile = "STANDARD_GRUPPENPROFIL"

    struct Request: Codable, Equatable {
        let profile: String
        let shipments: [Entry]
    }

    struct Entry: Codable, Equatable {
        let product: String
        let billingNumber: String
        let refNo: String?
        let shipper: Party
        let consignee: Party
        let details: Details
        let services: Extras?
    }

    struct Party: Codable, Equatable {
        let name1: String
        let name2: String?
        let addressStreet: String
        let postalCode: String
        let city: String
        let country: String
    }

    struct Details: Codable, Equatable {
        let weight: Weight
        let dim: Dimension?
    }

    struct Weight: Codable, Equatable {
        let uom: String
        let value: Int
    }

    struct Dimension: Codable, Equatable {
        let uom: String
        let length: Int
        let width: Int
        let height: Int
    }

    struct Extras: Codable, Equatable {
        let namedPersonOnly: Bool?
        let bulkyGoods: Bool?
        let signedForByRecipient: Bool?
        let additionalInsurance: Money?
    }

    struct Money: Codable, Equatable {
        let currency: String
        let value: Double
    }

    static func request(_ order: LabelOrder, profile: String = defaultProfile) -> Request {
        Request(profile: profile, shipments: [
            Entry(
                product: order.product,
                billingNumber: order.billingNumber.filter(\.isNumber),
                refNo: order.reference,
                shipper: party(order.sender),
                consignee: party(order.recipient),
                details: Details(weight: Weight(uom: "g", value: order.weightGrams), dim: dimension(order.parcel)),
                services: services(order)),
        ])
    }

    private static func dimension(_ parcel: Parcel?) -> Dimension? {
        guard let parcel, parcel.isComplete else { return nil }
        return Dimension(uom: "cm", length: parcel.lengthCm, width: parcel.widthCm, height: parcel.heightCm)
    }

    private static func services(_ order: LabelOrder) -> Extras? {
        let insurance = (order.insuranceValue ?? 0) > 0 ? order.insuranceValue.map { Money(currency: "EUR", value: $0) } : nil
        guard order.namedPersonOnly || order.bulky || order.signature || insurance != nil else { return nil }
        return Extras(
            namedPersonOnly: order.namedPersonOnly ? true : nil,
            bulkyGoods: order.bulky ? true : nil,
            signedForByRecipient: order.signature ? true : nil,
            additionalInsurance: insurance)
    }

    private static func party(_ address: Address) -> Party {
        Party(
            name1: address.name1, name2: address.name2, addressStreet: address.streetLine,
            postalCode: address.postalCode.filter { !$0.isWhitespace }, city: address.city, country: address.country)
    }
}
