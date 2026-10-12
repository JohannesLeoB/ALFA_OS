import Foundation

public struct SevdeskCapabilityProfile: Sendable, Equatable, Codable {
    public let schemaVersion: String
    public let verifiedAt: Date

    public let tenantFingerprint: String

    public let offerOrderType: String

    public let verifiedDraftStatus: Int?

    public let saveOrderEndpointVersion: String

    public let supportsFreeTextPositionWithoutPart: Bool
    public let supportsDiscountField: Bool
    public let supportsOptionalPositionSemantics: Bool

    public let supportsStableInternalReference: Bool

    public let acceptedDateEncoding: String

    public let acceptedDecimalEncoding: String

    public let allowedTaxMappingsVersion: String

    public let profileSHA256: String

    public init(
        schemaVersion: String,
        verifiedAt: Date,
        tenantFingerprint: String,
        offerOrderType: String,
        verifiedDraftStatus: Int?,
        saveOrderEndpointVersion: String,
        supportsFreeTextPositionWithoutPart: Bool,
        supportsDiscountField: Bool,
        supportsOptionalPositionSemantics: Bool,
        supportsStableInternalReference: Bool,
        acceptedDateEncoding: String,
        acceptedDecimalEncoding: String,
        allowedTaxMappingsVersion: String,
        profileSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.verifiedAt = verifiedAt
        self.tenantFingerprint = tenantFingerprint
        self.offerOrderType = offerOrderType
        self.verifiedDraftStatus = verifiedDraftStatus
        self.saveOrderEndpointVersion = saveOrderEndpointVersion
        self.supportsFreeTextPositionWithoutPart = supportsFreeTextPositionWithoutPart
        self.supportsDiscountField = supportsDiscountField
        self.supportsOptionalPositionSemantics = supportsOptionalPositionSemantics
        self.supportsStableInternalReference = supportsStableInternalReference
        self.acceptedDateEncoding = acceptedDateEncoding
        self.acceptedDecimalEncoding = acceptedDecimalEncoding
        self.allowedTaxMappingsVersion = allowedTaxMappingsVersion
        self.profileSHA256 = profileSHA256
    }

    public var offerOrderTypeIsValid: Bool { offerOrderType == "AN" }

    public func isCurrentlyValid(maxAgeSeconds: TimeInterval = 7 * 24 * 3600, now: Date = Date()) -> Bool {
        now.timeIntervalSince(verifiedAt) <= maxAgeSeconds
    }

    public func istFreigegebenFürWrite(now: Date = Date()) -> Bool {
        offerOrderTypeIsValid && isCurrentlyValid(now: now)
    }
}

public enum SevdeskWriteMode: Sendable, Equatable {
    case readOnly
    case draftOnly(profile: SevdeskCapabilityProfile)

    public func istSchreibbar(now: Date = Date()) -> Bool {
        guard case .draftOnly(let profile) = self else { return false }
        return profile.istFreigegebenFürWrite(now: now)
    }
}
