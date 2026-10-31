import Core
import Foundation

struct LabelOrder: Sendable, Equatable {
    static let defaultProduct = "V01PAK"

    var sender: Address
    var recipient: Address
    var weightGrams: Int
    var product: String
    var billingNumber: String
    var reference: String?
    var parcel: Parcel?
    var insuranceValue: Double?
    var namedPersonOnly: Bool
    var bulky: Bool
    var signature: Bool

    init(
        sender: Address, recipient: Address, weightGrams: Int, product: String = LabelOrder.defaultProduct,
        billingNumber: String, reference: String? = nil, parcel: Parcel? = nil, insuranceValue: Double? = nil,
        namedPersonOnly: Bool = false, bulky: Bool = false, signature: Bool = false
    ) {
        self.sender = sender
        self.recipient = recipient
        self.weightGrams = weightGrams
        self.product = product
        self.billingNumber = billingNumber
        self.reference = reference
        self.parcel = parcel
        self.insuranceValue = insuranceValue
        self.namedPersonOnly = namedPersonOnly
        self.bulky = bulky
        self.signature = signature
    }
}

public enum LabelOrderIssue: String, Sendable, Equatable, CaseIterable {
    case recipientName
    case recipientStreet
    case recipientPostalCode
    case recipientCity
    case senderIncomplete
    case weight
    case billingNumber

    var key: String { "shipping.issue." + rawValue }
}

struct Parcel: Sendable, Equatable {
    var lengthCm: Int
    var widthCm: Int
    var heightCm: Int

    init(lengthCm: Int, widthCm: Int, heightCm: Int) {
        self.lengthCm = lengthCm
        self.widthCm = widthCm
        self.heightCm = heightCm
    }

    var isComplete: Bool { lengthCm > 0 && widthCm > 0 && heightCm > 0 }
}

struct LabelResult: Sendable, Equatable {
    let trackingNumber: String
    let labelBase64: String?
    let statusText: String?

    init(trackingNumber: String, labelBase64: String?, statusText: String?) {
        self.trackingNumber = trackingNumber
        self.labelBase64 = labelBase64
        self.statusText = statusText
    }
}

struct Address: Sendable, Equatable {
    var name1: String
    var name2: String?
    var street: String
    var houseNumber: String
    var postalCode: String
    var city: String
    var country: String

    init(
        name1: String, name2: String? = nil, street: String, houseNumber: String, postalCode: String, city: String,
        country: String = "DEU"
    ) {
        self.name1 = name1
        let trimmed = name2?.trimmingCharacters(in: .whitespaces)
        self.name2 = trimmed?.isEmpty == false ? trimmed : nil
        self.street = street
        self.houseNumber = houseNumber
        self.postalCode = postalCode
        self.city = city
        self.country = country
    }

    var streetLine: String {
        houseNumber.isEmpty ? street : "\(street) \(houseNumber)"
    }

    static func parsed(
        name: String, line: String?, postalCode: String?, city: String?, country: String = "DEU"
    ) -> Address {
        let split = AddressSplitParser.parse(line ?? "")
        return Address(
            name1: name.trimmingCharacters(in: .whitespaces),
            street: split.street.trimmingCharacters(in: .whitespaces),
            houseNumber: (split.houseNumber ?? "").trimmingCharacters(in: .whitespaces),
            postalCode: (postalCode ?? "").trimmingCharacters(in: .whitespaces),
            city: (city ?? "").trimmingCharacters(in: .whitespaces),
            country: country)
    }
}

struct LabelCredentials: Equatable, Sendable {
    var apiKey: String
    var apiSecret: String
    var user: String
    var password: String
    var billingNumber: String
    var sender: Address?

    init(
        apiKey: String, apiSecret: String, user: String, password: String, billingNumber: String,
        sender: Address? = nil
    ) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.user = user
        self.password = password
        self.billingNumber = billingNumber
        self.sender = sender
    }
}

public struct Shipment: Codable, Sendable, Equatable, Identifiable {
    var trackingNumber: String
    var carrier: Carrier
    var label: String
    var status: TrackingStatus
    var statusText: String?
    var projectNumber: String?

    public var id: String { trackingNumber }

    init(
        trackingNumber: String, carrier: Carrier, label: String, status: TrackingStatus = .unknown,
        statusText: String? = nil, projectNumber: String? = nil
    ) {
        self.trackingNumber = trackingNumber
        self.carrier = carrier
        self.label = label
        self.status = status
        self.statusText = statusText
        self.projectNumber = projectNumber
    }
}

enum Carrier: String, Codable, Sendable, CaseIterable, Equatable {
    case dhl
    case hermes
    case unknown
}

enum TrackingStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case registered
    case inTransit
    case outForDelivery
    case delivered
    case exception
    case unknown

    var key: String { "shipping.status." + rawValue }
}

public enum ShippingFailure: Error, Equatable, Sendable {
    case noKey
    case noCredentials
    case unsupported
    case incomplete([LabelOrderIssue])
    case http(Int)
    case transport(String)
    case parse(String)

    var detail: String {
        switch self {
        case .noKey: "noKey"
        case .noCredentials: "noCredentials"
        case .unsupported: "unsupported"
        case .incomplete(let issues): "incomplete " + issues.map(\.rawValue).joined(separator: ",")
        case .http(let code): "http \(code)"
        case .transport(let reason): "transport \(reason)"
        case .parse(let reason): "parse \(reason)"
        }
    }
}
