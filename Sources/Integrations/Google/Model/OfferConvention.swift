public struct OfferConvention: Codable, Equatable, Sendable {
    public var incomingFolderKeyword: String
    public var outgoingFolderKeyword: String
    public var purchaseOrderFolderKeyword: String
    public var invoiceFolderKeyword: String
    public var offerFolderKeyword: String
    public var orderFolderKeyword: String
    public var prefixes: [String: OfferDocumentType]
    public var documentNumberPattern: String
    public var customerNumberPattern: String
    public var versionPattern: String

    public init(incomingFolderKeyword: String, outgoingFolderKeyword: String, purchaseOrderFolderKeyword: String,
                invoiceFolderKeyword: String, offerFolderKeyword: String, orderFolderKeyword: String,
                prefixes: [String: OfferDocumentType], documentNumberPattern: String,
                customerNumberPattern: String, versionPattern: String) {
        self.incomingFolderKeyword = incomingFolderKeyword
        self.outgoingFolderKeyword = outgoingFolderKeyword
        self.purchaseOrderFolderKeyword = purchaseOrderFolderKeyword
        self.invoiceFolderKeyword = invoiceFolderKeyword
        self.offerFolderKeyword = offerFolderKeyword
        self.orderFolderKeyword = orderFolderKeyword
        self.prefixes = prefixes
        self.documentNumberPattern = documentNumberPattern
        self.customerNumberPattern = customerNumberPattern
        self.versionPattern = versionPattern
    }
}

public enum OfferDocumentType: Int, Codable, CaseIterable, Sendable {
    case offer = 0
    case orderConfirmation = 1
    case depositInvoice = 2
    case finalInvoice = 3
    case incomingOffer = 4
    case purchaseOrder = 5
    case other = 99

    var labelKey: String {
        switch self {
        case .offer: "google.offer.type.offer"
        case .orderConfirmation: "google.offer.type.orderConfirmation"
        case .depositInvoice: "google.offer.type.depositInvoice"
        case .finalInvoice: "google.offer.type.finalInvoice"
        case .incomingOffer: "google.offer.type.incomingOffer"
        case .purchaseOrder: "google.offer.type.purchaseOrder"
        case .other: "google.offer.type.other"
        }
    }
}
