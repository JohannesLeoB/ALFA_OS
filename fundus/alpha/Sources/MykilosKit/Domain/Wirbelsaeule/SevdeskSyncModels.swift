import Foundation

public struct SevdeskMirror: Sendable, Equatable, Codable, Identifiable {
    public var id: String { sevdeskOrderID }

    public let sevdeskOrderID: String
    public let packageID: UUID

    public let sevdeskOrderType: String
    public let rawStatus: String
    public let orderNumber: String?
    public let sumNet: Decimal?
    public let sumTax: Decimal?
    public let sumGross: Decimal?
    public let remoteChangedAt: Date?

    public let remoteFingerprint: String
    public let syncedAt: Date

    public init(
        sevdeskOrderID: String, packageID: UUID, sevdeskOrderType: String, rawStatus: String,
        orderNumber: String? = nil, sumNet: Decimal? = nil, sumTax: Decimal? = nil, sumGross: Decimal? = nil,
        remoteChangedAt: Date? = nil, remoteFingerprint: String, syncedAt: Date
    ) {
        self.sevdeskOrderID = sevdeskOrderID
        self.packageID = packageID
        self.sevdeskOrderType = sevdeskOrderType
        self.rawStatus = rawStatus
        self.orderNumber = orderNumber
        self.sumNet = sumNet
        self.sumTax = sumTax
        self.sumGross = sumGross
        self.remoteChangedAt = remoteChangedAt
        self.remoteFingerprint = remoteFingerprint
        self.syncedAt = syncedAt
    }
}

public enum SevdeskMappingKind: String, Sendable, Equatable, Codable, CaseIterable {
    case contact = "CONTACT"
    case article = "ARTICLE"
    case unity = "UNITY"
    case tax = "TAX"
}

public struct SevdeskMapping: Sendable, Equatable, Codable, Identifiable {
    public var id: String { "\(kind.rawValue):\(mykilosID)" }

    public let kind: SevdeskMappingKind
    public let mykilosID: String
    public let sevdeskID: String
    public let verifiedAt: Date

    public let remoteFingerprint: String?

    public init(kind: SevdeskMappingKind, mykilosID: String, sevdeskID: String, verifiedAt: Date, remoteFingerprint: String? = nil) {
        self.kind = kind
        self.mykilosID = mykilosID
        self.sevdeskID = sevdeskID
        self.verifiedAt = verifiedAt
        self.remoteFingerprint = remoteFingerprint
    }
}
