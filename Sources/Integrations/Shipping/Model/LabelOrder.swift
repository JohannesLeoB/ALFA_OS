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
