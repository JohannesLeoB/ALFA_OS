import Foundation

public enum EstimateAdjustmentReason: String, Codable, CaseIterable, Identifiable {
    case materialUnderestimated = "material_underestimated"
    case executionComplexity = "execution_complexity"
    case supplierLevel = "supplier_level"
    case marketPrice = "market_price"
    case logistics
    case gutFeeling = "gut_feeling"
    case realOfferReceived = "real_offer_received"
    case finalInvoiceReceived = "final_invoice_received"
    case correctionError = "correction_error"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .materialUnderestimated: "Material unterschätzt"
        case .executionComplexity: "Ausführungskomplexität"
        case .supplierLevel: "Lieferantenniveau"
        case .marketPrice: "Marktpreis"
        case .logistics: "Logistik"
        case .gutFeeling: "Bauchgefühl"
        case .realOfferReceived: "Echtes Angebot erhalten"
        case .finalInvoiceReceived: "Schlussrechnung erhalten"
        case .correctionError: "Korrekturfehler"
        }
    }

    public var weight: Double {
        switch self {
        case .finalInvoiceReceived: 2.0
        case .realOfferReceived: 1.6
        case .gutFeeling: 0.6
        case .correctionError: 0.25
        default: 1.0
        }
    }
}

public enum EstimateAdjustmentTarget: String, Codable, CaseIterable, Identifiable {
    case wholeEstimate = "whole_estimate"
    case kitchenRun = "kitchen_run"
    case island
    case tallCabinetBlock = "tall_cabinet_block"
    case drawers
    case fronts
    case worktop
    case logistics

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wholeEstimate: "Gesamtschätzung"
        case .kitchenRun: "Küchenzeile"
        case .island: "Insel"
        case .tallCabinetBlock: "Hochschrankblock"
        case .drawers: "Schubkästen"
        case .fronts: "Fronten"
        case .worktop: "Arbeitsplatte"
        case .logistics: "Logistik"
        }
    }

    public func matches(component: EstimateComponent) -> Bool {
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

public enum LearningRecordStatus: String, Codable, CaseIterable {
    case active
    case inactive
    case superseded
    case promoted
    case candidate
    case strongCandidate = "strong_candidate"
    case reviewOutlier = "review_outlier"
}

public struct EstimateSession: Codable, Equatable, Identifiable {
    public let id: String
    public let createdAt: Date
    public let requestText: String
    public let baseLowNet: Decimal
    public let baseMidNet: Decimal
    public let baseHighNet: Decimal
    public let laborValueNet: Decimal
    public let evidenceIDs: [String]
    public let status: LearningRecordStatus

    public init(id: String = UUID().uuidString, createdAt: Date = Date(), requestText: String, baseLowNet: Decimal, baseMidNet: Decimal, baseHighNet: Decimal, laborValueNet: Decimal, evidenceIDs: [String], status: LearningRecordStatus = .active) {
        self.id = id
        self.createdAt = createdAt
        self.requestText = requestText
        self.baseLowNet = baseLowNet
        self.baseMidNet = baseMidNet
        self.baseHighNet = baseHighNet
        self.laborValueNet = laborValueNet
        self.evidenceIDs = evidenceIDs
        self.status = status
    }
}

public struct EstimateSessionComponent: Codable, Equatable, Identifiable {
    public let id: String
    public let sessionID: String
    public let componentIndex: Int
    public let componentClass: CalculationComponentClass
    public let componentType: ComponentType
    public let adjustmentTarget: EstimateAdjustmentTarget
    public let baseLowNet: Decimal
    public let baseMidNet: Decimal
    public let baseHighNet: Decimal
    public let evidenceIDs: [String]

    public init(id: String = UUID().uuidString, sessionID: String, componentIndex: Int, componentClass: CalculationComponentClass, componentType: ComponentType, adjustmentTarget: EstimateAdjustmentTarget, baseLowNet: Decimal, baseMidNet: Decimal, baseHighNet: Decimal, evidenceIDs: [String]) {
        self.id = id
        self.sessionID = sessionID
        self.componentIndex = componentIndex
        self.componentClass = componentClass
        self.componentType = componentType
        self.adjustmentTarget = adjustmentTarget
        self.baseLowNet = baseLowNet
        self.baseMidNet = baseMidNet
        self.baseHighNet = baseHighNet
        self.evidenceIDs = evidenceIDs
    }
}

public struct EstimateAdjustment: Codable, Equatable, Identifiable {
    public let id: String
    public let sessionID: String
    public let createdAt: Date
    public let percentDelta: Double
    public let euroDelta: Decimal?
    public let adjustedMidNet: Decimal
    public let reason: EstimateAdjustmentReason
    public let target: EstimateAdjustmentTarget
    public let status: LearningRecordStatus
    public let note: String

    public init(id: String = UUID().uuidString, sessionID: String, createdAt: Date = Date(), percentDelta: Double, euroDelta: Decimal?, adjustedMidNet: Decimal, reason: EstimateAdjustmentReason, target: EstimateAdjustmentTarget, status: LearningRecordStatus = .active, note: String = "") {
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.percentDelta = percentDelta
        self.euroDelta = euroDelta
        self.adjustedMidNet = adjustedMidNet
        self.reason = reason
        self.target = target
        self.status = status
        self.note = note
    }
}

public struct EstimateAdjustmentComponentTarget: Codable, Equatable, Identifiable {
    public let id: String
    public let adjustmentID: String
    public let sessionComponentID: String?
    public let target: EstimateAdjustmentTarget
    public let percentDelta: Double
    public let status: LearningRecordStatus

    public init(id: String = UUID().uuidString, adjustmentID: String, sessionComponentID: String?, target: EstimateAdjustmentTarget, percentDelta: Double, status: LearningRecordStatus = .active) {
        self.id = id
        self.adjustmentID = adjustmentID
        self.sessionComponentID = sessionComponentID
        self.target = target
        self.percentDelta = percentDelta
        self.status = status
    }
}

public struct CalibrationFactorCandidate: Codable, Equatable, Identifiable {
    public let id: String
    public let createdAt: Date
    public let reason: EstimateAdjustmentReason
    public let target: EstimateAdjustmentTarget
    public let sampleCount: Int
    public let weightedPercentDelta: Double
    public let multiplier: Decimal
    public let adjustmentIDs: [String]
    public let status: LearningRecordStatus
    public let note: String

    public init(id: String = UUID().uuidString, createdAt: Date = Date(), reason: EstimateAdjustmentReason, target: EstimateAdjustmentTarget, sampleCount: Int, weightedPercentDelta: Double, multiplier: Decimal, adjustmentIDs: [String], status: LearningRecordStatus, note: String) {
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

public struct ActiveCalibrationFactor: Codable, Equatable, Identifiable {
    public let id: String
    public let candidateID: String
    public let createdAt: Date
    public let reason: EstimateAdjustmentReason
    public let target: EstimateAdjustmentTarget
    public let multiplier: Decimal
    public let weightedPercentDelta: Double
    public let sampleCount: Int
    public let status: LearningRecordStatus

    public init(id: String = UUID().uuidString, candidateID: String, createdAt: Date = Date(), reason: EstimateAdjustmentReason, target: EstimateAdjustmentTarget, multiplier: Decimal, weightedPercentDelta: Double, sampleCount: Int, status: LearningRecordStatus = .active) {
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

public struct LearningAuditLogEntry: Codable, Equatable, Identifiable {
    public let id: String
    public let createdAt: Date
    public let entityID: String
    public let entityTable: String
    public let action: String
    public let message: String

    public init(id: String = UUID().uuidString, createdAt: Date = Date(), entityID: String, entityTable: String, action: String, message: String) {
        self.id = id
        self.createdAt = createdAt
        self.entityID = entityID
        self.entityTable = entityTable
        self.action = action
        self.message = message
    }
}

public struct AppliedCalibrationFactor: Codable, Equatable, Identifiable {
    public let id: String
    public let factorID: String
    public let reason: EstimateAdjustmentReason
    public let target: EstimateAdjustmentTarget
    public let multiplier: Decimal
    public let appliedDeltaNet: Decimal

    public init(id: String = UUID().uuidString, factorID: String, reason: EstimateAdjustmentReason, target: EstimateAdjustmentTarget, multiplier: Decimal, appliedDeltaNet: Decimal) {
        self.id = id
        self.factorID = factorID
        self.reason = reason
        self.target = target
        self.multiplier = multiplier
        self.appliedDeltaNet = appliedDeltaNet
    }
}

public protocol CalibrationFactorProviding {
    func activeCalibrationFactors() throws -> [ActiveCalibrationFactor]
}
