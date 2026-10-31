import Foundation

struct DriveFile: Identifiable, Equatable, Sendable {
    static let folderMime = "application/vnd.google-apps.folder"
    static let nativePrefix = "application/vnd.google-apps."

    var id: String
    var name: String
    var mimeType: String
    var modifiedAt: Date?
    var webViewLink: String?
    var size: Int?

    var isFolder: Bool { mimeType == Self.folderMime }

    var isNative: Bool { mimeType.hasPrefix(Self.nativePrefix) }

    var typeLabel: String {
        switch mimeType {
        case Self.folderMime: "google.drive.type.folder"
        case "application/pdf": "google.drive.type.pdf"
        case "application/vnd.google-apps.spreadsheet": "google.drive.type.sheet"
        case "application/vnd.google-apps.document": "google.drive.type.document"
        case "application/vnd.google-apps.presentation": "google.drive.type.presentation"
        default:
            if mimeType.hasPrefix("image/") { "google.drive.type.image" }
            else if let subtype = mimeType.split(separator: "/").last, !subtype.isEmpty { subtype.uppercased() }
            else { "google.drive.type.file" }
        }
    }
}

struct CalendarEvent: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var startsAt: Date?
    var endsAt: Date?
    var isAllDay: Bool
    var location: String?
    var calendarID: String
}

struct EventCalendar: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
}

struct Contact: Identifiable, Equatable, Sendable {
    var id: String
    var displayName: String
    var email: String?
    var phone: String?
    var organization: String?
}

public struct DriveConfig: Codable, Equatable, Sendable {
    public var projectsRoot: String
    public var forbiddenFolderIDs: Set<String>
    public var offers: OfferConvention

    public init(projectsRoot: String, forbiddenFolderIDs: Set<String>, offers: OfferConvention) {
        self.projectsRoot = projectsRoot
        self.forbiddenFolderIDs = forbiddenFolderIDs
        self.offers = offers
    }
}

public struct DriveRoot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

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
