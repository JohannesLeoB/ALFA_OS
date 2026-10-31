import Foundation

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

enum LabelOrderEngine {
    static let billingNumberDigits = 14

    static func issues(_ order: LabelOrder) -> [LabelOrderIssue] {
        var found: [LabelOrderIssue] = []
        if order.recipient.name1.isEmpty { found.append(.recipientName) }
        if order.recipient.street.isEmpty { found.append(.recipientStreet) }
        if isValidPostalCode(order.recipient.postalCode) == false { found.append(.recipientPostalCode) }
        if order.recipient.city.isEmpty { found.append(.recipientCity) }
        if order.sender.name1.isEmpty || order.sender.street.isEmpty
            || isValidPostalCode(order.sender.postalCode) == false || order.sender.city.isEmpty {
            found.append(.senderIncomplete)
        }
        if order.weightGrams <= 0 { found.append(.weight) }
        if order.billingNumber.filter(\.isNumber).count != billingNumberDigits { found.append(.billingNumber) }
        return found
    }

    static func isValidPostalCode(_ code: String) -> Bool {
        let digits = code.filter { !$0.isWhitespace }
        return digits.count == 5 && digits.allSatisfy(\.isNumber)
    }
}

enum ReferenceEngine {
    static let maxLength = 35
    static let numberPrefixPattern = "^\\d{4}[_-]\\d{2,4}[_-]"

    static func commission(fromProjectName name: String) -> String {
        var text = name.trimmingCharacters(in: .whitespaces)
        if let regex = try? NSRegularExpression(pattern: numberPrefixPattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        }
        text = text.replacingOccurrences(of: "_", with: " ")
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        return text.trimmingCharacters(in: .whitespaces)
    }

    static func reference(projectNumber: String?, projectName: String?) -> String? {
        let commission = projectName.map(commission(fromProjectName:)).flatMap(nonEmpty)
        let number = projectNumber.map { $0.trimmingCharacters(in: .whitespaces) }.flatMap(nonEmpty)
        let parts = [commission, number].compactMap { $0 }
        guard parts.isEmpty == false else { return nil }
        return String(parts.joined(separator: " \u{00B7} ").prefix(maxLength))
    }

    private static func nonEmpty(_ text: String) -> String? {
        text.isEmpty ? nil : text
    }
}
