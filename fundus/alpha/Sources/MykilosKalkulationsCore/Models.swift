import Foundation

public enum ComponentType: String, Codable, CaseIterable, Equatable, Sendable {
    case baseCabinetRun = "base_cabinet_run"
    case island
    case tallCabinetBlock = "tall_cabinet_block"
    case wallCabinets = "wall_cabinets"
    case stoneCountertop = "stone_countertop"
    case worktopScope = "worktop_scope"
    case applianceScope = "appliance_scope"
    case drawerAddon = "drawer_addon"
    case delivery
    case installation
    case projectLogistics = "project_logistics"
    case aggregateKitchen = "aggregate_kitchen"
    case other

    public static func fromBrainComponent(_ value: String) -> ComponentType {
        let lower = value.lowercased()
        if lower.contains("küchenzeile") || lower.contains("kuechenzeile") { return .baseCabinetRun }
        if lower.contains("insel") || lower.contains("block") { return .island }
        if lower.contains("hochschrank") { return .tallCabinetBlock }
        if lower.contains("arbeitsplatte") || lower.contains("steinmetz") { return .stoneCountertop }
        if lower.contains("montage") { return .installation }
        if lower.contains("lieferung") || lower.contains("handling") { return .delivery }
        if lower.contains("gesamt") || lower.contains("küche") || lower.contains("kueche") { return .aggregateKitchen }
        return .other
    }

    public var displayName: String {
        switch self {
        case .baseCabinetRun: "Küchenzeile/Unterschränke"
        case .island: "Insel/Block"
        case .tallCabinetBlock: "Hochschrankblock"
        case .wallCabinets: "Hängeschränke"
        case .stoneCountertop: "Arbeitsplatte/Stein"
        case .worktopScope: "Arbeitsplatten-Scope"
        case .applianceScope: "Geräte-Scope"
        case .drawerAddon: "Schubkästen/Beschläge"
        case .delivery: "Lieferung"
        case .installation: "Montage"
        case .projectLogistics: "Projektlogistik"
        case .aggregateKitchen: "Gesamtküche"
        case .other: "Sonstiges"
        }
    }
}

public enum CalculationComponentClass: String, Codable, CaseIterable, Equatable, Hashable {
    case baseUnit = "base_unit"
    case kitchenRun = "kitchen_run"
    case island
    case tallCabinetBlock = "tall_cabinet_block"
    case aggregateKitchen = "aggregate_kitchen"
    case worktopSurface = "worktop_surface"
    case logistics
    case applianceHandling = "appliance_handling"
    case alternative
    case unknownReview = "unknown_review"

    public var displayName: String {
        switch self {
        case .baseUnit: "Einzel-Unterschrank"
        case .kitchenRun: "Küchenzeile"
        case .island: "Insel"
        case .tallCabinetBlock: "Hochschrankblock"
        case .aggregateKitchen: "Gesamtküche"
        case .worktopSurface: "Arbeitsplatte"
        case .logistics: "Lieferung/Montage"
        case .applianceHandling: "Gerätehandling"
        case .alternative: "Alternative/Mehrpreis"
        case .unknownReview: "Review"
        }
    }
}

public enum AnchorSourceKind: String, Codable, Equatable {
    case pdfOffer = "pdf_offer"
    case ruleBasedAnchor = "rule_based_anchor"

    public var displayName: String {
        switch self {
        case .pdfOffer: "PDF-Angebot"
        case .ruleBasedAnchor: "Regelbasiert"
        }
    }
}

public struct SourceDocument: Codable, Equatable, Identifiable {
    public var id: String { sourceDocumentID }
    public let sourceDocumentID: String
    public let filename: String
    public let supplier: String
    public let project: String
    public let documentDate: String?
    public let documentType: String
    public let sha256: String
    public let pageCount: Int

    public init(sourceDocumentID: String, filename: String, supplier: String, project: String, documentDate: String?, documentType: String, sha256: String, pageCount: Int) {
        self.sourceDocumentID = sourceDocumentID
        self.filename = filename
        self.supplier = supplier
        self.project = project
        self.documentDate = documentDate
        self.documentType = documentType
        self.sha256 = sha256
        self.pageCount = pageCount
    }
}

public struct SourcePage: Codable, Equatable, Identifiable {
    public var id: String { sourcePageID }
    public let sourcePageID: String
    public let sourceDocumentID: String
    public let pageNumber: Int
    public let pageText: String
    public let extractionQuality: Double
}

public struct OfferPositionBlock: Codable, Equatable, Identifiable {
    public var id: String { blockID }
    public let blockID: String
    public let sourceDocumentID: String
    public let pageNumber: Int
    public let supplier: String
    public let project: String
    public let trade: String
    public let componentType: ComponentType
    public let netPrice: Decimal
    public let grossPrice: Decimal?
    public let lengthM: Double?
    public let areaM2: Double?
    public let drawerCount: Int
    public let materials: [String]
    public let scopeFlags: [String]
    public let originalText: String
    public let confidence: Double
    public let riskFlags: [String]
    public let status: String
}

public struct ComponentPriceAtom: Codable, Equatable, Identifiable {
    public var id: String { atomID }
    public let atomID: String
    public let sourceBlockID: String
    public let componentType: ComponentType
    public let normalizedNetPrice: Decimal
    public let normalizedUnitPrice: Decimal
    public let unit: String
    public let materialClass: String
    public let complexityClass: String
    public let scopeClass: String
    public let confidence: Double
    public let isActive: Bool
}

public struct CandidateReleaseDecision: Codable, Equatable, Identifiable {
    public var id: String { candidateID }
    public let candidateID: String
    public let sourceFile: String
    public let page: Int
    public let supplier: String
    public let project: String
    public let component: String
    public let trade: String
    public let priceNetGuess: Decimal
    public let confidence: Double
    public let duplicateCount: Int
    public let currentStatus: String
    public let proposedStatus: String
    public let supersededBy: String?
    public let decisionScore: Double
    public let decisionReason: String
    public let helpNeeded: String
    public let title: String
    public let evidenceQuote: String
    public let carryforwardRuleStatus: String
    public let ruleSafePriceNet: Decimal?
    public let ruleNotes: String
    public let componentClass: CalculationComponentClass
    public let sourceKind: AnchorSourceKind

    public let equipmentDensity: KitchenEquipmentDensity

    public var componentType: ComponentType { ComponentType.fromBrainComponent(component) }
    public var isReleaseReady: Bool { proposedStatus.hasPrefix("release_") }
    public var isSuperseded: Bool { proposedStatus.hasPrefix("superseded_") || supersededBy?.isEmpty == false }
    public var isManualReview: Bool { proposedStatus.hasPrefix("review_") }

    public init(candidateID: String, sourceFile: String, page: Int, supplier: String, project: String, component: String, trade: String, priceNetGuess: Decimal, confidence: Double, duplicateCount: Int, currentStatus: String, proposedStatus: String, supersededBy: String?, decisionScore: Double, decisionReason: String, helpNeeded: String, title: String, evidenceQuote: String, carryforwardRuleStatus: String, ruleSafePriceNet: Decimal?, ruleNotes: String, componentClass: CalculationComponentClass? = nil, sourceKind: AnchorSourceKind = .pdfOffer, equipmentDensity: KitchenEquipmentDensity = .unknown) {
        self.candidateID = candidateID
        self.sourceFile = sourceFile
        self.page = page
        self.supplier = supplier
        self.project = project
        self.component = component
        self.trade = trade
        self.priceNetGuess = priceNetGuess
        self.confidence = confidence
        self.duplicateCount = duplicateCount
        self.currentStatus = currentStatus
        self.proposedStatus = proposedStatus
        self.supersededBy = supersededBy
        self.decisionScore = decisionScore
        self.decisionReason = decisionReason
        self.helpNeeded = helpNeeded
        self.title = title
        self.evidenceQuote = evidenceQuote
        self.carryforwardRuleStatus = carryforwardRuleStatus
        self.ruleSafePriceNet = ruleSafePriceNet
        self.ruleNotes = ruleNotes
        self.componentClass = componentClass ?? CandidateReleaseDecision.classify(component: component, trade: trade, title: title, evidenceQuote: evidenceQuote, proposedStatus: proposedStatus)
        self.sourceKind = sourceKind
        self.equipmentDensity = equipmentDensity
    }

    public func withEquipmentDensity(_ density: KitchenEquipmentDensity) -> CandidateReleaseDecision {
        CandidateReleaseDecision(
            candidateID: candidateID, sourceFile: sourceFile, page: page, supplier: supplier,
            project: project, component: component, trade: trade, priceNetGuess: priceNetGuess,
            confidence: confidence, duplicateCount: duplicateCount, currentStatus: currentStatus,
            proposedStatus: proposedStatus, supersededBy: supersededBy, decisionScore: decisionScore,
            decisionReason: decisionReason, helpNeeded: helpNeeded, title: title,
            evidenceQuote: evidenceQuote, carryforwardRuleStatus: carryforwardRuleStatus,
            ruleSafePriceNet: ruleSafePriceNet, ruleNotes: ruleNotes, componentClass: componentClass,
            sourceKind: sourceKind, equipmentDensity: density
        )
    }

    public static func classify(component: String, trade: String, title: String, evidenceQuote: String, proposedStatus: String) -> CalculationComponentClass {
        let lower = [component, trade, title, evidenceQuote, proposedStatus].joined(separator: " ").lowercased()
        if lower.contains("alternative") || lower.contains("mehrpreis") || lower.contains("eventual") { return .alternative }
        if lower.contains("gerät") || lower.contains("geraet") { return .applianceHandling }
        if lower.contains("montage") || lower.contains("lieferung") || lower.contains("transport") || lower.contains("handling") { return .logistics }
        if lower.contains("arbeitsplatte") || lower.contains("steinmetz") || lower.contains("dekton") || lower.contains("quarzit") { return .worktopSurface }
        if lower.contains("pantry") { return .unknownReview }
        if lower.contains("hochschrank") { return .tallCabinetBlock }
        if lower.contains("insel") || lower.contains("block") { return .island }
        if lower.contains("küchenzeile") || lower.contains("kuechenzeile") || lower.contains("zeile") || lower.contains("unterschrank") { return .kitchenRun }
        if lower.contains("gesamt") || lower.contains("küche") || lower.contains("kueche") { return .aggregateKitchen }
        return .unknownReview
    }
}

public struct EstimateRequest: Codable, Equatable {
    public let rawText: String
    public var components: [EstimateComponent]
    public var materials: Set<String>
    public var scope: ScopeFlags

    public init(rawText: String, components: [EstimateComponent], materials: Set<String>, scope: ScopeFlags) {
        self.rawText = rawText
        self.components = components
        self.materials = materials
        self.scope = scope
    }
}

public struct ScopeFlags: Codable, Equatable {
    public var includesDelivery: Bool
    public var includesInstallation: Bool
    public var excludesAppliances: Bool
    public var excludesWorktop: Bool
    public var excludesStone: Bool
    public var notes: [String]

    public init(includesDelivery: Bool = false, includesInstallation: Bool = false, excludesAppliances: Bool = false, excludesWorktop: Bool = false, excludesStone: Bool = false, notes: [String] = []) {
        self.includesDelivery = includesDelivery
        self.includesInstallation = includesInstallation
        self.excludesAppliances = excludesAppliances
        self.excludesWorktop = excludesWorktop
        self.excludesStone = excludesStone
        self.notes = notes
    }
}

public struct EstimateComponent: Codable, Equatable, Identifiable {
    public let id: UUID
    public let type: ComponentType
    public var quantity: Double
    public var unit: String
    public var widthM: Double?
    public var heightM: Double?
    public var depthM: Double?
    public var drawerCount: Int
    public var materials: Set<String>
    public var scopeNotes: [String]
    public var componentClass: CalculationComponentClass

    public init(id: UUID = UUID(), type: ComponentType, quantity: Double, unit: String, widthM: Double? = nil, heightM: Double? = nil, depthM: Double? = nil, drawerCount: Int = 0, materials: Set<String> = [], scopeNotes: [String] = [], componentClass: CalculationComponentClass? = nil) {
        self.id = id
        self.type = type
        self.quantity = quantity
        self.unit = unit
        self.widthM = widthM
        self.heightM = heightM
        self.depthM = depthM
        self.drawerCount = drawerCount
        self.materials = materials
        self.scopeNotes = scopeNotes
        self.componentClass = componentClass ?? EstimateComponent.defaultClass(for: type, unit: unit)
    }

    public static func defaultClass(for type: ComponentType, unit: String) -> CalculationComponentClass {
        switch type {
        case .baseCabinetRun: unit == "piece" ? .baseUnit : .kitchenRun
        case .island: .island
        case .tallCabinetBlock: .tallCabinetBlock
        case .wallCabinets: .kitchenRun
        case .stoneCountertop, .worktopScope: .worktopSurface
        case .drawerAddon: .baseUnit
        case .delivery, .installation, .projectLogistics: .logistics
        case .applianceScope: .applianceHandling
        case .aggregateKitchen: .aggregateKitchen
        case .other: .unknownReview
        }
    }
}

public struct ComponentRequirement: Codable, Equatable, Identifiable {
    public let id: UUID
    public let component: EstimateComponent
    public let allowedComponentClasses: Set<CalculationComponentClass>
    public let forbiddenComponentClasses: Set<CalculationComponentClass>
    public let minEvidenceCount: Int
    public let maxScaleFactor: Double
    public let requiredScopeCompatibility: [String]

    public init(id: UUID = UUID(), component: EstimateComponent, allowedComponentClasses: Set<CalculationComponentClass>, forbiddenComponentClasses: Set<CalculationComponentClass>, minEvidenceCount: Int, maxScaleFactor: Double, requiredScopeCompatibility: [String]) {
        self.id = id
        self.component = component
        self.allowedComponentClasses = allowedComponentClasses
        self.forbiddenComponentClasses = forbiddenComponentClasses
        self.minEvidenceCount = minEvidenceCount
        self.maxScaleFactor = maxScaleFactor
        self.requiredScopeCompatibility = requiredScopeCompatibility
    }
}

public struct EvidenceCase: Codable, Equatable, Identifiable {
    public var id: String { priceAnchorID }
    public let priceAnchorID: String
    public let sourceFile: String
    public let page: Int
    public let supplier: String
    public let project: String
    public let component: String
    public let scope: String
    public let confidence: Double
    public let netPrice: Decimal
    public let unitPrice: Decimal?
    public let quote: String
    public let risksExcluded: [String]

    public init(priceAnchorID: String, sourceFile: String, page: Int, supplier: String, project: String, component: String, scope: String, confidence: Double, netPrice: Decimal, unitPrice: Decimal?, quote: String, risksExcluded: [String]) {
        self.priceAnchorID = priceAnchorID
        self.sourceFile = sourceFile
        self.page = page
        self.supplier = supplier
        self.project = project
        self.component = component
        self.scope = scope
        self.confidence = confidence
        self.netPrice = netPrice
        self.unitPrice = unitPrice
        self.quote = quote
        self.risksExcluded = risksExcluded
    }
}

public struct PriceBand: Codable, Equatable, Sendable {
    public let low: Decimal
    public let expected: Decimal
    public let high: Decimal
    public let currency: String

    public init(low: Decimal, expected: Decimal, high: Decimal, currency: String) {
        self.low = low
        self.expected = expected
        self.high = high
        self.currency = currency
    }
}

public struct EstimateLine: Codable, Equatable, Identifiable {
    public var id: UUID
    public let component: EstimateComponent
    public let priceBand: PriceBand
    public let evidence: [EvidenceCase]
    public let rationale: String

    public init(id: UUID, component: EstimateComponent, priceBand: PriceBand, evidence: [EvidenceCase], rationale: String) {
        self.id = id
        self.component = component
        self.priceBand = priceBand
        self.evidence = evidence
        self.rationale = rationale
    }
}

public struct EstimateResult: Codable, Equatable {
    public let request: EstimateRequest
    public let lines: [EstimateLine]
    public let baseTotalBand: PriceBand
    public let totalBand: PriceBand
    public let baseLaborValue: Decimal
    public let laborValue: Decimal
    public let calibrationApplications: [AppliedCalibrationFactor]
    public let confidence: Double
    public let evidence: [EvidenceCase]
    public let dataGaps: [String]
    public let excludedRisks: [String]
    public let scopeNotes: [String]
    public let bottomUpCost: BottomUpEstimate?

    public init(request: EstimateRequest, lines: [EstimateLine], totalBand: PriceBand, laborValue: Decimal, confidence: Double, evidence: [EvidenceCase], dataGaps: [String], excludedRisks: [String], scopeNotes: [String], baseTotalBand: PriceBand? = nil, baseLaborValue: Decimal? = nil, calibrationApplications: [AppliedCalibrationFactor] = [], bottomUpCost: BottomUpEstimate? = nil) {
        self.bottomUpCost = bottomUpCost
        self.request = request
        self.lines = lines
        self.baseTotalBand = baseTotalBand ?? totalBand
        self.totalBand = totalBand
        self.baseLaborValue = baseLaborValue ?? laborValue
        self.laborValue = laborValue
        self.calibrationApplications = calibrationApplications
        self.confidence = confidence
        self.evidence = evidence
        self.dataGaps = dataGaps
        self.excludedRisks = excludedRisks
        self.scopeNotes = scopeNotes
    }
}

public struct BrainSummary: Codable, Equatable {
    public let sourceDocuments: Int
    public let sourcePages: Int
    public let offerPositionBlocks: Int
    public let componentPriceAtoms: Int
    public let moneyObservations: Int
    public let candidateReleaseDecisions: Int
    public let releaseReadyActiveAnchors: Int
    public let manualReviewItems: Int
    public let supersededItems: Int
    public let statusCounts: [String: Int]

    public init(sourceDocuments: Int, sourcePages: Int, offerPositionBlocks: Int, componentPriceAtoms: Int, moneyObservations: Int, candidateReleaseDecisions: Int, releaseReadyActiveAnchors: Int, manualReviewItems: Int, supersededItems: Int, statusCounts: [String: Int]) {
        self.sourceDocuments = sourceDocuments
        self.sourcePages = sourcePages
        self.offerPositionBlocks = offerPositionBlocks
        self.componentPriceAtoms = componentPriceAtoms
        self.moneyObservations = moneyObservations
        self.candidateReleaseDecisions = candidateReleaseDecisions
        self.releaseReadyActiveAnchors = releaseReadyActiveAnchors
        self.manualReviewItems = manualReviewItems
        self.supersededItems = supersededItems
        self.statusCounts = statusCounts
    }
}
