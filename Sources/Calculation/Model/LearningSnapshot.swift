import Foundation

struct LearningSnapshot: Sendable, Equatable {
    let sessions: Int
    let adjustments: Int
    let outliers: Int
    let activeFactors: [EstimationFactor]
    let candidates: [EstimationFactor]

    init(sessions: Int, adjustments: Int, outliers: Int, activeFactors: [EstimationFactor], candidates: [EstimationFactor]) {
        self.sessions = sessions
        self.adjustments = adjustments
        self.outliers = outliers
        self.activeFactors = activeFactors
        self.candidates = candidates
    }

    var isEmpty: Bool { activeFactors.isEmpty && candidates.isEmpty }
}

struct EstimationFactor: Sendable, Equatable, Identifiable {
    let id: String
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let percent: Double
    let sampleCount: Int
    let status: LearningStatus

    init(id: String, reason: AdjustmentReason, target: AdjustmentTarget, percent: Double, sampleCount: Int, status: LearningStatus) {
        self.id = id
        self.reason = reason
        self.target = target
        self.percent = percent
        self.sampleCount = sampleCount
        self.status = status
    }
}

struct LearningAuditEntry: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let entityID: String
    let entityTable: String
    let action: String
    let detail: String

    init(id: String = UUID().uuidString, createdAt: Date = Date(), entityID: String, entityTable: String, action: String, detail: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.entityID = entityID
        self.entityTable = entityTable
        self.action = action
        self.detail = detail
    }
}

enum LearningStatus: String, CaseIterable, Sendable {
    case active
    case inactive
    case superseded
    case promoted
    case candidate
    case strongCandidate = "strong_candidate"
    case reviewOutlier = "review_outlier"
}

struct FactorCandidate: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let sampleCount: Int
    let weightedPercentDelta: Double
    let multiplier: Decimal
    let adjustmentIDs: [String]
    let status: LearningStatus
    let note: Notice

    init(id: String = UUID().uuidString, createdAt: Date = Date(), reason: AdjustmentReason, target: AdjustmentTarget, sampleCount: Int, weightedPercentDelta: Double, multiplier: Decimal, adjustmentIDs: [String], status: LearningStatus, note: Notice) {
        self.id = id
        self.createdAt = createdAt
        self.reason = reason
        self.target = target
        self.sampleCount = sampleCount
        self.weightedPercentDelta = weightedPercentDelta
        self.multiplier = multiplier
        self.adjustmentIDs = adjustmentIDs
        self.status = status
        self.note = note
    }
}

struct ActiveFactor: Equatable, Identifiable, Sendable {
    let id: String
    let candidateID: String
    let createdAt: Date
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let multiplier: Decimal
    let weightedPercentDelta: Double
    let sampleCount: Int
    let status: LearningStatus

    init(id: String = UUID().uuidString, candidateID: String, createdAt: Date = Date(), reason: AdjustmentReason, target: AdjustmentTarget, multiplier: Decimal, weightedPercentDelta: Double, sampleCount: Int, status: LearningStatus = .active) {
        self.id = id
        self.candidateID = candidateID
        self.createdAt = createdAt
        self.reason = reason
        self.target = target
        self.multiplier = multiplier
        self.weightedPercentDelta = weightedPercentDelta
        self.sampleCount = sampleCount
        self.status = status
    }
}

enum AdjustmentReason: String, CaseIterable, Identifiable, Sendable {
    case materialUnderestimated = "material_underestimated"
    case executionComplexity = "execution_complexity"
    case supplierLevel = "supplier_level"
    case marketPrice = "market_price"
    case logistics
    case gutFeeling = "gut_feeling"
    case realOfferReceived = "real_offer_received"
    case finalInvoiceReceived = "final_invoice_received"
    case correctionError = "correction_error"

    var id: String { rawValue }

    var localizationKey: String { "calc.reason.\(rawValue)" }

    var weight: Double {
        switch self {
        case .finalInvoiceReceived: 2.0
        case .realOfferReceived: 1.6
        case .gutFeeling: 0.6
        case .correctionError: 0.25
        default: 1.0
        }
    }
}

enum AdjustmentTarget: String, CaseIterable, Identifiable, Sendable {
    case wholeEstimate = "whole_estimate"
    case kitchenRun = "kitchen_run"
    case island
    case tallCabinetBlock = "tall_cabinet_block"
    case drawers
    case fronts
    case worktop
    case logistics

    var id: String { rawValue }

    var localizationKey: String { "calc.target.\(rawValue)" }

    func matches(component: EstimateComponent) -> Bool {
        switch self {
        case .wholeEstimate:
            return true
        case .kitchenRun:
            return component.componentClass == .kitchenRun
        case .island:
            return component.componentClass == .island
        case .tallCabinetBlock:
            return component.componentClass == .tallCabinetBlock
        case .drawers:
            return component.type == .drawerAddon || component.drawerCount > 0
        case .fronts:
            return component.materials.contains("linoleum") || component.materials.contains("eiche") || component.materials.contains("edelstahl") || component.materials.contains("fenix")
        case .worktop:
            return component.componentClass == .worktopSurface
        case .logistics:
            return component.componentClass == .logistics
        }
    }
}

struct ComponentAdjustmentTarget: Equatable, Identifiable, Sendable {
    let id: String
    let adjustmentID: String
    let sessionComponentID: String?
    let target: AdjustmentTarget
    let percentDelta: Double
    let status: LearningStatus

    init(id: String = UUID().uuidString, adjustmentID: String, sessionComponentID: String?, target: AdjustmentTarget, percentDelta: Double, status: LearningStatus = .active) {
        self.id = id
        self.adjustmentID = adjustmentID
        self.sessionComponentID = sessionComponentID
        self.target = target
        self.percentDelta = percentDelta
        self.status = status
    }
}

public struct WorkshopFactors: Equatable, Sendable {
    public var values: [String: Double]

    public init(_ values: [String: Double] = [:]) {
        self.values = values
    }
}

struct ReviewAction: Equatable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let candidateID: String
    let kind: ReviewActionKind
    let note: String

    init(id: UUID = UUID(), createdAt: Date = Date(), candidateID: String, kind: ReviewActionKind, note: String) {
        self.id = id
        self.createdAt = createdAt
        self.candidateID = candidateID
        self.kind = kind
        self.note = note
    }
}

enum ReviewActionKind: String, Sendable {
    case releaseAsActiveAnchor
    case addUserNote
}

public struct CandidateReleaseDecision: Equatable, Identifiable, Sendable {
    public var id: String { candidateID }
    let candidateID: String
    let sourceFile: String
    let page: Int
    let supplier: String
    let project: String
    let component: String
    let trade: String
    let priceNetGuess: Decimal
    let confidence: Double
    let duplicateCount: Int
    let currentStatus: String
    let proposedStatus: String
    let supersededBy: String?
    let decisionScore: Double
    let decisionReason: String
    let helpNeeded: String
    let title: String
    let evidenceQuote: String
    let carryforwardRuleStatus: String
    let ruleSafePriceNet: Decimal?
    let ruleNotes: String
    let componentClass: ComponentClass
    let sourceKind: AnchorSourceKind
    let equipmentDensity: EquipmentDensity

    var isReleaseReady: Bool { proposedStatus.hasPrefix("release_") }
    var isSuperseded: Bool { proposedStatus.hasPrefix("superseded_") || supersededBy?.isEmpty == false }

    var materialsText: String { [title, evidenceQuote].joined(separator: " ") }

    var lengthM: Double? {
        let pattern = #"([0-9]+(?:[,.][0-9]+)?)\s*(?:lfm|meter|m)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let text = [title, evidenceQuote].joined(separator: " ")
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, range: nsRange),
              let range = Range(result.range(at: 1), in: text) else { return nil }
        return NumberParser.double(String(text[range]))
    }

    init(candidateID: String, sourceFile: String, page: Int, supplier: String, project: String, component: String, trade: String, priceNetGuess: Decimal, confidence: Double, duplicateCount: Int, currentStatus: String, proposedStatus: String, supersededBy: String?, decisionScore: Double, decisionReason: String, helpNeeded: String, title: String, evidenceQuote: String, carryforwardRuleStatus: String, ruleSafePriceNet: Decimal?, ruleNotes: String, componentClass: ComponentClass? = nil, sourceKind: AnchorSourceKind = .pdfOffer, equipmentDensity: EquipmentDensity = .unknown) {
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

    func withEquipmentDensity(_ density: EquipmentDensity) -> CandidateReleaseDecision {
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

    static func classify(component: String, trade: String, title: String, evidenceQuote: String, proposedStatus: String) -> ComponentClass {
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

enum AnchorSourceKind: String, Equatable, Sendable {
    case pdfOffer = "pdf_offer"
    case ruleBasedAnchor = "rule_based_anchor"
}

enum AnchorInflation {
    static let annualRate = 0.04
    static let maxYears = 6

    static func year(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let digits = Array(raw)
        for start in 0...(max(0, digits.count - 4)) where start + 4 <= digits.count {
            let window = digits[start..<start + 4]
            guard window.allSatisfy(\.isNumber) else { continue }
            let value = Int(String(window)) ?? 0
            if value >= 1900 && value <= 2100 { return value }
        }
        return nil
    }

    static func factor(offerYear: Int?, referenceYear: Int) -> Decimal {
        guard let offerYear, offerYear < referenceYear else { return 1 }
        let years = min(referenceYear - offerYear, maxYears)
        let grown = pow(1 + annualRate, Double(years))
        return Decimal(grown)
    }

    static func confidenceFactor(offerYear: Int?, referenceYear: Int) -> Double {
        guard let offerYear else { return 0.7 }
        let years = max(0, min(referenceYear - offerYear, maxYears))
        return max(0.55, 1 - Double(years) * 0.06)
    }
}

struct SupplierOffer: Equatable, Sendable {
    let sourceRecordID: String
    let kind: SupplierOfferKind
    let partner: String
    let date: String
    let netEur: Decimal
    let status: SupplierOfferStatus

    init(sourceRecordID: String, kind: SupplierOfferKind, partner: String, date: String, netEur: Decimal, status: SupplierOfferStatus) {
        self.sourceRecordID = sourceRecordID
        self.kind = kind
        self.partner = partner
        self.date = date
        self.netEur = netEur
        self.status = status
    }
}

enum SupplierOfferKind: String, CaseIterable, Sendable {
    case incoming
    case outgoing
}

enum SupplierOfferStatus: String, CaseIterable, Sendable {
    case draft
    case received
    case open
    case accepted
    case rejected
    case order
    case finalInvoice = "final_invoice"

    func learningReason(kind: SupplierOfferKind) -> AdjustmentReason? {
        switch (kind, self) {
        case (.incoming, .finalInvoice): .finalInvoiceReceived
        case (.incoming, .order): .finalInvoiceReceived
        case (.incoming, .accepted): .realOfferReceived
        case (.outgoing, .accepted): .realOfferReceived
        case (.outgoing, .order): .realOfferReceived
        case (.outgoing, .rejected): .marketPrice
        default: nil
        }
    }
}

struct SupplierOfferSyncEntry: Equatable, Identifiable, Sendable {
    let id: String
    let sourceRecordID: String
    let offerKind: SupplierOfferKind
    let netEur: Decimal
    let offerStatus: SupplierOfferStatus
    let partner: String
    let importedAt: Date
    let offerDate: String?

    init(id: String = UUID().uuidString, sourceRecordID: String, offerKind: SupplierOfferKind, netEur: Decimal, offerStatus: SupplierOfferStatus, partner: String, importedAt: Date = Date(), offerDate: String? = nil) {
        self.id = id
        self.sourceRecordID = sourceRecordID
        self.offerKind = offerKind
        self.netEur = netEur
        self.offerStatus = offerStatus
        self.partner = partner
        self.importedAt = importedAt
        self.offerDate = offerDate
    }
}

struct PdfPosition: Equatable, Identifiable, Sendable {
    let id: String
    let sourceFile: String
    let pageNumber: Int
    let title: String
    let componentType: ComponentType
    let netPrice: Decimal
    let unit: String
    let quantity: Double
    let confidence: Double
    let extractedAt: Date

    init(id: String, sourceFile: String, pageNumber: Int, title: String, componentType: ComponentType, netPrice: Decimal, unit: String, quantity: Double, confidence: Double, extractedAt: Date) {
        self.id = id
        self.sourceFile = sourceFile
        self.pageNumber = pageNumber
        self.title = title
        self.componentType = componentType
        self.netPrice = netPrice
        self.unit = unit
        self.quantity = quantity
        self.confidence = confidence
        self.extractedAt = extractedAt
    }

    var componentClass: ComponentClass {
        switch componentType {
        case .baseCabinetRun: .kitchenRun
        case .island: .island
        case .tallCabinetBlock: .tallCabinetBlock
        case .wallCabinets, .drawerAddon: .unknownReview
        case .stoneCountertop, .worktopScope: .worktopSurface
        case .applianceScope: .applianceHandling
        case .delivery, .installation, .projectLogistics: .logistics
        case .aggregateKitchen: .aggregateKitchen
        case .other: .unknownReview
        }
    }
}

extension Decimal {
    init(finite value: Double) {
        self = value.isFinite ? Decimal(value) : Decimal(0)
    }

    var double: Double { NSDecimalNumber(decimal: self).doubleValue }
}
