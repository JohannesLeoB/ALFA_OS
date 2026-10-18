import Foundation

public enum ÜbergabeStatus: String, Sendable, Codable, Hashable, CaseIterable {
    case building = "BUILDING"

    case readyForReview = "READY_FOR_REVIEW"

    case approvedForDraft = "APPROVED_FOR_DRAFT"

    case queued = "QUEUED"

    case processing = "PROCESSING"

    case sevdeskDraftCreated = "SEVDESK_DRAFT_CREATED"

    case sevdeskDraftUpdated = "SEVDESK_DRAFT_UPDATED"

    case retryWait = "RETRY_WAIT"

    case reviewRequired = "REVIEW_REQUIRED"

    case failedPermanent = "FAILED_PERMANENT"

    case writeLocked = "WRITE_LOCKED"

    public func erlaubteNachfolger() -> Set<ÜbergabeStatus> {
        switch self {
        case .building:          return [.readyForReview]
        case .readyForReview:    return [.approvedForDraft, .building]
        case .approvedForDraft:  return [.queued, .readyForReview]
        case .queued:            return [.processing]
        case .processing:        return [.sevdeskDraftCreated, .sevdeskDraftUpdated,
                                          .retryWait, .reviewRequired, .failedPermanent]
        case .sevdeskDraftCreated: return [.writeLocked]
        case .sevdeskDraftUpdated: return [.writeLocked]
        case .retryWait:         return [.queued]
        case .reviewRequired:    return [.readyForReview]
        case .failedPermanent:   return []
        case .writeLocked:       return []
        }
    }

    public func kannÜbergehenNach(_ next: ÜbergabeStatus) -> Bool {
        erlaubteNachfolger().contains(next)
    }

    public var istSchreibbar: Bool {
        switch self {
        case .approvedForDraft, .queued, .processing: return true
        default: return false
        }
    }

    public var istTerminal: Bool {
        switch self {
        case .failedPermanent, .writeLocked: return true
        default: return false
        }
    }
}

public enum CommercialProcessType: String, Sendable, Codable, Hashable, CaseIterable {
    case costEstimate           = "COST_ESTIMATE"
    case proposal               = "PROPOSAL"
    case offerDraft             = "OFFER_DRAFT"
    case variant                = "VARIANT"
    case changeProposal         = "CHANGE_PROPOSAL"
    case amendmentProposal      = "AMENDMENT_PROPOSAL"
}

public enum CommercialDraftPositionKind: String, Sendable, Codable, Hashable, CaseIterable {
    case mappedCatalogArticle   = "MAPPED_CATALOG_ARTICLE"
    case freeTextItem           = "FREE_TEXT_ITEM"
    case service                = "SERVICE"
    case heading                = "HEADING"
    case optionalItem           = "OPTIONAL_ITEM"
    case alternativeItem        = "ALTERNATIVE_ITEM"
    case surcharge              = "SURCHARGE"
    case discountProposal       = "DISCOUNT_PROPOSAL"
}

public enum PositionMappingState: String, Sendable, Codable, Hashable {
    case supportedDirectly          = "SUPPORTED_DIRECTLY"
    case supportedAfterTransformation = "SUPPORTED_AFTER_TRANSFORMATION"
    case internalOnly               = "INTERNAL_ONLY"
    case blockedRequiresReview      = "BLOCKED_REQUIRES_REVIEW"
}

public struct CommercialDraftPosition: Sendable, Equatable, Codable {
    enum CodingKeys: String, CodingKey { case positionID, packageID, sequenz, kind, mykilosArtikelID, sevdeskPartID, label = "bezeichnung", beschreibung, quantity = "menge", einheitText, vkNettoEinzel, rabattProzent, steuerKontextID, mappingState, positionSHA256 }

    public let positionID: UUID
    public let packageID: UUID
    public let sequenz: Int
    public let kind: CommercialDraftPositionKind

    public let mykilosArtikelID: String?

    public let sevdeskPartID: String?

    public let label: String

    public let beschreibung: String?
    public let quantity: Decimal

    public let einheitText: String

    public let vkNettoEinzel: Decimal?

    public let rabattProzent: Decimal?
    public let steuerKontextID: String

    public let mappingState: PositionMappingState

    public let positionSHA256: String

    public var summeNetto: Decimal? {
        guard let vk = vkNettoEinzel else { return nil }
        return vk * quantity
    }

    public init(
        positionID: UUID = UUID(),
        packageID: UUID,
        sequenz: Int,
        kind: CommercialDraftPositionKind,
        mykilosArtikelID: String? = nil,
        sevdeskPartID: String? = nil,
        label: String,
        beschreibung: String? = nil,
        quantity: Decimal,
        einheitText: String,
        vkNettoEinzel: Decimal?,
        rabattProzent: Decimal? = nil,
        steuerKontextID: String,
        mappingState: PositionMappingState,
        positionSHA256: String
    ) {
        self.positionID = positionID
        self.packageID = packageID
        self.sequenz = sequenz
        self.kind = kind
        self.mykilosArtikelID = mykilosArtikelID
        self.sevdeskPartID = sevdeskPartID
        self.label = label
        self.beschreibung = beschreibung
        self.quantity = quantity
        self.einheitText = einheitText
        self.vkNettoEinzel = vkNettoEinzel
        self.rabattProzent = rabattProzent
        self.steuerKontextID = steuerKontextID
        self.mappingState = mappingState
        self.positionSHA256 = positionSHA256
    }
}

public struct CommercialDraftPackage: Sendable, Equatable, Codable {
    enum CodingKeys: String, CodingKey { case packageID, revision, createdAt, createdByUserID, projektID, projektCode, contactID, processType, title = "titel", einleitungsText, schlussText, currency, steuerKontextID, positionen, expectedNet, expectedTax, expectedGross, payloadSchemaVersion, payloadSHA256, übergabeStatus, sevdeskOrderID, sevdeskOrderNumber, lastErrorCode }

    public let packageID: UUID
    public let revision: Int
    public let createdAt: Date
    public let createdByUserID: String

    public let projektID: String
    public let projektCode: String
    public let contactID: String

    public let processType: CommercialProcessType
    public let title: String
    public let einleitungsText: String?
    public let schlussText: String?

    public let currency: String
    public let steuerKontextID: String

    public let positionen: [CommercialDraftPosition]

    public let expectedNet: Decimal

    public let expectedTax: Decimal

    public let expectedGross: Decimal

    public let payloadSchemaVersion: Int

    public let payloadSHA256: String

    public let übergabeStatus: ÜbergabeStatus

    public let sevdeskOrderID: String?

    public let sevdeskOrderNumber: String?

    public let lastErrorCode: String?

    public init(
        packageID: UUID = UUID(),
        revision: Int = 1,
        createdAt: Date,
        createdByUserID: String,
        projektID: String,
        projektCode: String,
        contactID: String,
        processType: CommercialProcessType,
        title: String,
        einleitungsText: String? = nil,
        schlussText: String? = nil,
        currency: String = "EUR",
        steuerKontextID: String,
        positionen: [CommercialDraftPosition],
        expectedNet: Decimal,
        expectedTax: Decimal,
        expectedGross: Decimal,
        payloadSchemaVersion: Int = 1,
        payloadSHA256: String,
        übergabeStatus: ÜbergabeStatus = .building,
        sevdeskOrderID: String? = nil,
        sevdeskOrderNumber: String? = nil,
        lastErrorCode: String? = nil
    ) {
        self.packageID = packageID
        self.revision = revision
        self.createdAt = createdAt
        self.createdByUserID = createdByUserID
        self.projektID = projektID
        self.projektCode = projektCode
        self.contactID = contactID
        self.processType = processType
        self.title = title
        self.einleitungsText = einleitungsText
        self.schlussText = schlussText
        self.currency = currency
        self.steuerKontextID = steuerKontextID
        self.positionen = positionen
        self.expectedNet = expectedNet
        self.expectedTax = expectedTax
        self.expectedGross = expectedGross
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadSHA256 = payloadSHA256
        self.übergabeStatus = übergabeStatus
        self.sevdeskOrderID = sevdeskOrderID
        self.sevdeskOrderNumber = sevdeskOrderNumber
        self.lastErrorCode = lastErrorCode
    }

    public func mitStatus(_ neuerStatus: ÜbergabeStatus, fehlerCode: String? = nil) -> CommercialDraftPackage {
        CommercialDraftPackage(
            packageID: packageID, revision: revision, createdAt: createdAt,
            createdByUserID: createdByUserID, projektID: projektID, projektCode: projektCode,
            contactID: contactID, processType: processType, title: title,
            einleitungsText: einleitungsText, schlussText: schlussText,
            currency: currency, steuerKontextID: steuerKontextID,
            positionen: positionen, expectedNet: expectedNet, expectedTax: expectedTax,
            expectedGross: expectedGross, payloadSchemaVersion: payloadSchemaVersion,
            payloadSHA256: payloadSHA256, übergabeStatus: neuerStatus,
            sevdeskOrderID: sevdeskOrderID, sevdeskOrderNumber: sevdeskOrderNumber,
            lastErrorCode: fehlerCode ?? lastErrorCode)
    }

    public func mitNächsterRevision(neuePositionen: [CommercialDraftPosition], neuerHash: String) -> CommercialDraftPackage {
        CommercialDraftPackage(
            packageID: packageID, revision: revision + 1, createdAt: createdAt,
            createdByUserID: createdByUserID, projektID: projektID, projektCode: projektCode,
            contactID: contactID, processType: processType, title: title,
            einleitungsText: einleitungsText, schlussText: schlussText,
            currency: currency, steuerKontextID: steuerKontextID,
            positionen: neuePositionen, expectedNet: expectedNet, expectedTax: expectedTax,
            expectedGross: expectedGross, payloadSchemaVersion: payloadSchemaVersion,
            payloadSHA256: neuerHash, übergabeStatus: .building,
            sevdeskOrderID: sevdeskOrderID, sevdeskOrderNumber: sevdeskOrderNumber,
            lastErrorCode: nil)
    }

    public var hatBlockiertePositionen: Bool {
        positionen.contains { $0.mappingState == .blockedRequiresReview }
    }

    public var allePositionenÜbertragbar: Bool {
        !hatBlockiertePositionen
            && positionen.allSatisfy { $0.mappingState != .internalOnly || $0.vkNettoEinzel == nil }
    }
}
