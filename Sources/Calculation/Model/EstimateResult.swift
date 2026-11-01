import Foundation

struct EstimateResult: Equatable, Sendable {
    let request: EstimateInput
    let lines: [EstimateLine]
    let baseTotalBand: PriceBand
    let totalBand: PriceBand
    let baseLaborValue: Decimal
    let laborValue: Decimal
    let calibrationApplications: [AppliedFactor]
    let confidence: Double
    let evidence: [EvidenceCase]
    let dataGaps: [Notice]
    let excludedRisks: [Notice]
    let scopeNotes: [Notice]
    let bottomUpCost: BottomUpEstimate?

    init(request: EstimateInput, lines: [EstimateLine], totalBand: PriceBand, laborValue: Decimal, confidence: Double, evidence: [EvidenceCase], dataGaps: [Notice], excludedRisks: [Notice], scopeNotes: [Notice], baseTotalBand: PriceBand? = nil, baseLaborValue: Decimal? = nil, calibrationApplications: [AppliedFactor] = [], bottomUpCost: BottomUpEstimate? = nil) {
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

struct EstimateLine: Equatable, Identifiable, Sendable {
    let id: UUID
    let component: EstimateComponent
    let priceBand: PriceBand
    let evidence: [EvidenceCase]
    let rationale: Notice
}

struct AppliedFactor: Equatable, Identifiable, Sendable {
    let id: String
    let factorID: String
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let multiplier: Decimal
    let appliedDeltaNet: Decimal

    init(id: String = UUID().uuidString, factorID: String, reason: AdjustmentReason, target: AdjustmentTarget, multiplier: Decimal, appliedDeltaNet: Decimal) {
        self.id = id
        self.factorID = factorID
        self.reason = reason
        self.target = target
        self.multiplier = multiplier
        self.appliedDeltaNet = appliedDeltaNet
    }
}

struct BottomUpEstimate: Equatable, Sendable {
    let laborNet: Decimal
    let materialNet: Decimal
    let total: Decimal
    let carcassEquivalents: Double
    let frontAreaM2: Double
    let stageBreakdown: [StageCost]
    let assumptions: [Notice]
}

struct StageCost: Equatable, Sendable {
    let stage: String
    let minutesPerCarcass: Double
    let ratePerHour: Decimal
    let cost: Decimal
}

struct EvidenceCase: Equatable, Identifiable, Sendable {
    var id: String { priceAnchorID }
    let priceAnchorID: String
    let sourceFile: String
    let page: Int
    let supplier: String
    let project: String
    let component: String
    let scope: String
    let confidence: Double
    let netPrice: Decimal
    let unitPrice: Decimal?
    let quote: String
    let risksExcluded: [Notice]
}

struct EstimateInput: Equatable, Sendable {
    let rawText: String
    var components: [EstimateComponent]
    var materials: Set<String>
    var scope: ScopeFlags
}

struct ScopeFlags: Equatable, Sendable {
    var includesDelivery = false
    var includesInstallation = false
    var excludesAppliances = false
    var excludesWorktop = false
    var excludesStone = false
    var notes: [Notice] = []
}

struct EstimateComponent: Equatable, Identifiable, Sendable {
    let id: UUID
    let type: ComponentType
    var quantity: Double
    var unit: String
    var widthM: Double?
    var heightM: Double?
    var depthM: Double?
    var drawerCount: Int
    var materials: Set<String>
    var scopeNotes: [Notice]
    var componentClass: ComponentClass

    init(id: UUID = UUID(), type: ComponentType, quantity: Double, unit: String, widthM: Double? = nil, heightM: Double? = nil, depthM: Double? = nil, drawerCount: Int = 0, materials: Set<String> = [], scopeNotes: [Notice] = [], componentClass: ComponentClass? = nil) {
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

    static func defaultClass(for type: ComponentType, unit: String) -> ComponentClass {
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

struct EstimateAdjustment: Equatable, Identifiable, Sendable {
    let id: String
    let sessionID: String
    let createdAt: Date
    let percentDelta: Double
    let euroDelta: Decimal?
    let adjustedMidNet: Decimal
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let status: LearningStatus
    let note: String

    init(id: String = UUID().uuidString, sessionID: String, createdAt: Date = Date(), percentDelta: Double, euroDelta: Decimal?, adjustedMidNet: Decimal, reason: AdjustmentReason, target: AdjustmentTarget, status: LearningStatus = .active, note: String = "") {
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

public struct EstimateBreakdownLine: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, Equatable {
        case estimated
        case fixed
        case open
    }

    public let label: Notice
    public let amountNet: Double?
    public let kind: Kind

    public init(label: Notice, amountNet: Double?, kind: Kind) {
        self.label = label
        self.amountNet = amountNet
        self.kind = kind
    }
}

public struct EstimateOverride: Sendable, Equatable {
    var carcassCount: Int?
    var frontExecution: String?
    var drawersLegrabox: Int?
    var drawersSolid: Int?
    var workshop: String?
    var distanceKm: Double?

    public init(carcassCount: Int? = nil, frontExecution: String? = nil,
                drawersLegrabox: Int? = nil, drawersSolid: Int? = nil,
                workshop: String? = nil, distanceKm: Double? = nil) {
        self.carcassCount = carcassCount
        self.frontExecution = frontExecution
        self.drawersLegrabox = drawersLegrabox
        self.drawersSolid = drawersSolid
        self.workshop = workshop
        self.distanceKm = distanceKm
    }

    var isEmpty: Bool {
        carcassCount == nil && frontExecution == nil && drawersLegrabox == nil
            && drawersSolid == nil && workshop == nil && distanceKm == nil
    }

    var openFields: [String] {
        var out: [String] = []
        if carcassCount == nil { out.append("calc.field.carcassCount") }
        if frontExecution == nil { out.append("calc.field.frontExecution") }
        if workshop == nil { out.append("calc.field.workshop") }
        return out
    }
}

struct EstimateSession: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let requestText: String
    let baseLowNet: Decimal
    let baseMidNet: Decimal
    let baseHighNet: Decimal
    let laborValueNet: Decimal
    let evidenceIDs: [String]
    let status: LearningStatus

    init(id: String = UUID().uuidString, createdAt: Date = Date(), requestText: String, baseLowNet: Decimal, baseMidNet: Decimal, baseHighNet: Decimal, laborValueNet: Decimal, evidenceIDs: [String], status: LearningStatus = .active) {
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

struct SessionComponent: Equatable, Identifiable, Sendable {
    let id: String
    let sessionID: String
    let componentIndex: Int
    let componentClass: ComponentClass
    let componentType: ComponentType
    let adjustmentTarget: AdjustmentTarget
    let baseLowNet: Decimal
    let baseMidNet: Decimal
    let baseHighNet: Decimal
    let evidenceIDs: [String]

    init(id: String = UUID().uuidString, sessionID: String, componentIndex: Int, componentClass: ComponentClass, componentType: ComponentType, adjustmentTarget: AdjustmentTarget, baseLowNet: Decimal, baseMidNet: Decimal, baseHighNet: Decimal, evidenceIDs: [String]) {
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

public struct CostEstimate: Sendable, Equatable {
    public let estimateID: String
    public let projectID: String
    public let minNet: Double
    public let maxNet: Double
    public let midNet: Double
    public let confidence: Double
    public let evidenceCount: Int
    let costFloor: Double
    let costFloorRatio: Double
    let topEvidence: [PriceEvidence]
    public let modelLabel: Notice?
    public let hints: [Notice]
    public let lines: [EstimateBreakdownLine]
    public let excludes: [Notice]

    public init(
        estimateID: String,
        projectID: String,
        minNet: Double,
        maxNet: Double,
        midNet: Double,
        confidence: Double,
        evidenceCount: Int,
        costFloor: Double,
        costFloorRatio: Double,
        topEvidence: [PriceEvidence],
        modelLabel: Notice? = nil,
        hints: [Notice] = [],
        lines: [EstimateBreakdownLine] = [],
        excludes: [Notice] = []
    ) {
        self.estimateID = estimateID
        self.projectID = projectID
        self.minNet = minNet
        self.maxNet = maxNet
        self.midNet = midNet
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.costFloor = costFloor
        self.costFloorRatio = costFloorRatio
        self.topEvidence = topEvidence
        self.modelLabel = modelLabel
        self.hints = hints
        self.lines = lines
        self.excludes = excludes
    }
}

enum CostModel {
    struct Stage: Sendable {
        let key: String
        let ratePerHour: Decimal
        let minutesPerCarcass: Double
    }

    static let stages: [Stage] = [
        Stage(key: "calc.stage.preparation", ratePerHour: 104, minutesPerCarcass: 60),
        Stage(key: "calc.stage.cutting", ratePerHour: 100, minutesPerCarcass: 15),
        Stage(key: "calc.stage.edging", ratePerHour: 95, minutesPerCarcass: 30),
        Stage(key: "calc.stage.cnc", ratePerHour: 115, minutesPerCarcass: 20),
        Stage(key: "calc.stage.bench", ratePerHour: 85, minutesPerCarcass: 60),
        Stage(key: "calc.stage.stock", ratePerHour: 85, minutesPerCarcass: 10),
        Stage(key: "calc.stage.loading", ratePerHour: 85, minutesPerCarcass: 30),
        Stage(key: "calc.stage.installation", ratePerHour: 82, minutesPerCarcass: 120),
    ]

    static let carcassWidthM = 0.6
    static let carcassSurfaceM2 = 2.93
    static let baseFrontHeightM = 0.72

    static let decorBoardPerM2: Decimal = Decimal(string: "9.02")!
    static let decorFrontPerM2: Decimal = Decimal(string: "14.02")!
    static let mdfPerM2: Decimal = Decimal(string: "16.56")!
    static let veneerBoardPerM2: Decimal = Decimal(string: "21.90")!
    static let preLacqueredPerM2: Decimal = Decimal(string: "27.55")!
    static let linoleumFrontPerM2: Decimal = Decimal(string: "45.00")!

    static var laborPerCarcass: Decimal {
        stages.reduce(Decimal(0)) { $0 + $1.ratePerHour * Decimal(finite: $1.minutesPerCarcass / 60) }
    }

    static func frontPrice(materials: Set<String>) -> (price: Decimal, materialKey: String) {
        if materials.contains("furnier") || materials.contains("eiche") || materials.contains("nussbaum")
            || materials.contains("massivholz") || materials.contains("esche") || materials.contains("ahorn") {
            return (veneerBoardPerM2, "calc.frontMaterial.veneer")
        }
        if materials.contains("lack") || materials.contains("fenix") {
            return (preLacqueredPerM2, "calc.frontMaterial.lacquer")
        }
        if materials.contains("linoleum") {
            return (linoleumFrontPerM2, "calc.frontMaterial.linoleum")
        }
        if materials.contains("mdf") {
            return (mdfPerM2, "calc.frontMaterial.mdf")
        }
        return (decorFrontPerM2, "calc.frontMaterial.decor")
    }
}

struct PriceBand: Equatable, Sendable {
    let low: Decimal
    let expected: Decimal
    let high: Decimal
    let currency: String
}

public struct PriceEvidence: Sendable, Equatable {
    let supplier: String
    let document: String
    let page: Int?
    let originalQuote: String
    let netPrice: Double

    init(supplier: String, document: String, page: Int?, originalQuote: String, netPrice: Double) {
        self.supplier = supplier
        self.document = document
        self.page = page
        self.originalQuote = originalQuote
        self.netPrice = netPrice
    }
}

public struct Notice: Codable, Equatable, Sendable {
    public let key: String
    public let arguments: [String]

    public init(_ key: String, _ arguments: [String] = []) {
        self.key = key
        self.arguments = arguments
    }

    public init?(json: String) {
        guard let notice = try? JSONDecoder().decode(Notice.self, from: Data(json.utf8)) else { return nil }
        self = notice
    }

    var json: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static let sizeEstimated = Notice("size_estimated")
    static let sizeImplausible = Notice("size_implausible")

    static func amount(_ value: Decimal) -> String {
        let handler = NSDecimalNumberHandler(
            roundingMode: .bankers, scale: 0, raiseOnExactness: false,
            raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        return NSDecimalNumber(decimal: value).rounding(accordingToBehavior: handler).stringValue
    }

    static func fixed(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }

    static func measure(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
