import Foundation

struct CarcassSpec: Equatable, Sendable {
    var carcassCount: Int
    var frontExecution: FrontExecution
    var drawersLegrabox: Int
    var drawersSolid: Int
    var distanceKm: Double?
    var installationBasis: InstallationBasis
    var installationHourlyRate: Double?
    var workshop: String?

    init(carcassCount: Int, frontExecution: FrontExecution, drawersLegrabox: Int = 0,
         drawersSolid: Int = 0, distanceKm: Double? = nil, installationBasis: InstallationBasis = .included,
         installationHourlyRate: Double? = nil, workshop: String? = nil) {
        self.carcassCount = max(0, carcassCount)
        self.frontExecution = frontExecution
        self.drawersLegrabox = max(0, drawersLegrabox)
        self.drawersSolid = max(0, drawersSolid)
        self.distanceKm = distanceKm
        self.installationBasis = installationBasis
        self.installationHourlyRate = installationHourlyRate
        self.workshop = workshop
    }
}

enum InstallationBasis: String, Sendable {
    case included = "inklusive"
    case separate = "separat"
    case unknown = "unbekannt"
}

struct CarcassEstimate: Equatable, Sendable {
    let band: PriceBand
    let fixedCost: Decimal
    let travel: Decimal
    let variable: Decimal
    let drawers: Decimal
    let installationShare: Decimal
    let furnitureWithoutInstallation: Decimal
    let carcassCount: Int
    let frontExecution: FrontExecution
    let assumptions: [Notice]
    let excludes: [Exclusion]
    let parameterSnapshot: [String: Double]
}

enum Exclusion: String, CaseIterable, Sendable {
    case worktop
    case appliances
    case margin

    var detail: Notice { Notice("calc.exclude.\(rawValue)") }
    var label: Notice { Notice("calc.exclude.\(rawValue).label") }
    var hint: Notice { Notice("calc.hint.excluded.\(rawValue)") }
}

public struct CarcassParameters: Equatable, Sendable {
    var fixedBase: Decimal
    var variablePerCarcass: Decimal
    var frontMultipliers: [String: Double]
    var drawerLegraboxPrice: Decimal
    var drawerSolidPrice: Decimal
    var travelPerKm: Decimal
    var travelFreeKm: Double
    var installationHoursPerCarcass: Double
    var installationHourlyRate: Decimal
    var bandLow: Double
    var bandHigh: Double
    var bandLowThin: Double
    var bandHighThin: Double
    var workshopFactors: [String: Double]

    func frontMultiplier(for front: FrontExecution) -> Double {
        frontMultipliers[front.rawValue] ?? front.variableMultiplier
    }

    func workshopFactor(for name: String?) -> Double {
        guard let name, name.isEmpty == false else { return 1.0 }
        if let hit = workshopFactors[String(name.lowercased().filter { $0.isLetter || $0.isNumber })] { return hit }
        for token in name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            if let hit = workshopFactors[String(token)] { return hit }
        }
        return 1.0
    }

    public static func seed(workshopFactors: WorkshopFactors = WorkshopFactors()) -> CarcassParameters {
        CarcassParameters(
            fixedBase: 6500,
            variablePerCarcass: 685,
            frontMultipliers: Dictionary(uniqueKeysWithValues: FrontExecution.allCases.map { ($0.rawValue, $0.variableMultiplier) }),
            drawerLegraboxPrice: 70,
            drawerSolidPrice: 132,
            travelPerKm: 8,
            travelFreeKm: 30,
            installationHoursPerCarcass: 3.3,
            installationHourlyRate: 81,
            bandLow: 0.72,
            bandHigh: 1.40,
            bandLowThin: 0.62,
            bandHighThin: 1.58,
            workshopFactors: workshopFactors.values)
    }

    public static func from(parameters p: [String: Double], fallback: CarcassParameters) -> CarcassParameters {
        func money(_ key: String, _ fallbackValue: Decimal) -> Decimal { p[key].map { Decimal($0) } ?? fallbackValue }
        func number(_ key: String, _ fallbackValue: Double) -> Double { p[key] ?? fallbackValue }
        var fronts = fallback.frontMultipliers
        for front in FrontExecution.allCases {
            if let value = p["front_faktor_\(front.rawValue)"] { fronts[front.rawValue] = value }
        }
        var workshops = fallback.workshopFactors
        for (key, value) in p where key.hasPrefix("werkstatt_faktor_") {
            workshops[String(key.dropFirst("werkstatt_faktor_".count))] = value
        }
        return CarcassParameters(
            fixedBase: money("fixkosten_sockel", fallback.fixedBase),
            variablePerCarcass: money("variabel_pro_korpus", fallback.variablePerCarcass),
            frontMultipliers: fronts,
            drawerLegraboxPrice: money("schub_legrabox_eur", fallback.drawerLegraboxPrice),
            drawerSolidPrice: money("schub_holz_eur", fallback.drawerSolidPrice),
            travelPerKm: money("anfahrt_pro_km", fallback.travelPerKm),
            travelFreeKm: number("anfahrt_frei_km", fallback.travelFreeKm),
            installationHoursPerCarcass: number("montage_stunden_pro_korpus", fallback.installationHoursPerCarcass),
            installationHourlyRate: money("montage_stundensatz_default", fallback.installationHourlyRate),
            bandLow: number("band_low", fallback.bandLow),
            bandHigh: number("band_high", fallback.bandHigh),
            bandLowThin: number("band_low_thin", fallback.bandLowThin),
            bandHighThin: number("band_high_thin", fallback.bandHighThin),
            workshopFactors: workshops)
    }
}

struct CarcassAdjustment: Equatable, Identifiable, Sendable {
    let id: String
    let sessionID: String
    let createdAt: Date
    let target: CarcassCalibrationTarget
    let modelValue: Double
    let observedValue: Double
    let reason: AdjustmentReason
    let note: String
    let status: LearningStatus

    init(id: String = UUID().uuidString, sessionID: String, createdAt: Date = Date(),
         target: CarcassCalibrationTarget, modelValue: Double, observedValue: Double,
         reason: AdjustmentReason, note: String = "", status: LearningStatus = .active) {
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.target = target
        self.modelValue = modelValue
        self.observedValue = observedValue
        self.reason = reason
        self.note = note
        self.status = status
    }

    var percentDelta: Double {
        modelValue == 0 ? 0 : (observedValue - modelValue) / modelValue * 100
    }
}

struct CarcassCalibrationCandidate: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let target: CarcassCalibrationTarget
    let sampleCount: Int
    let weightedPercentDelta: Double
    let currentValue: Double
    let proposedValue: Double
    let adjustmentIDs: [String]
    let status: LearningStatus
    let note: Notice

    init(id: String, createdAt: Date = Date(), target: CarcassCalibrationTarget, sampleCount: Int,
         weightedPercentDelta: Double, currentValue: Double, proposedValue: Double,
         adjustmentIDs: [String], status: LearningStatus, note: Notice) {
        self.id = id
        self.createdAt = createdAt
        self.target = target
        self.sampleCount = sampleCount
        self.weightedPercentDelta = weightedPercentDelta
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.adjustmentIDs = adjustmentIDs
        self.status = status
        self.note = note
    }
}

enum CarcassCalibrationTarget: Equatable, Hashable, Sendable {
    case fixedBase
    case variablePerCarcass
    case frontFactor(FrontExecution)
    case workshopFactor(String)
    case installationHourlyRate
    case drawerSolid
    case drawerLegrabox
    case travelPerKm

    var key: String {
        switch self {
        case .fixedBase: "fixkosten_sockel"
        case .variablePerCarcass: "variabel_pro_korpus"
        case .frontFactor(let front): "front_faktor_\(front.rawValue)"
        case .workshopFactor(let workshop): "werkstatt_faktor_\(workshop)"
        case .installationHourlyRate: "montage_stundensatz_default"
        case .drawerSolid: "schub_holz_eur"
        case .drawerLegrabox: "schub_legrabox_eur"
        case .travelPerKm: "anfahrt_pro_km"
        }
    }

    var localizationKey: String {
        switch self {
        case .workshopFactor: "calc.carcassTarget.werkstatt_faktor"
        default: "calc.carcassTarget.\(key)"
        }
    }

    var detail: String {
        if case .workshopFactor(let workshop) = self { return workshop }
        return ""
    }

    init?(key: String) {
        switch key {
        case "fixkosten_sockel": self = .fixedBase
        case "variabel_pro_korpus": self = .variablePerCarcass
        case "montage_stundensatz_default": self = .installationHourlyRate
        case "schub_holz_eur": self = .drawerSolid
        case "schub_legrabox_eur": self = .drawerLegrabox
        case "anfahrt_pro_km": self = .travelPerKm
        default:
            if key.hasPrefix("front_faktor_"), let front = FrontExecution(rawValue: String(key.dropFirst("front_faktor_".count))) {
                self = .frontFactor(front)
            } else if key.hasPrefix("werkstatt_faktor_") {
                self = .workshopFactor(String(key.dropFirst("werkstatt_faktor_".count)))
            } else {
                return nil
            }
        }
    }
}

enum EquipmentDensity: String, Equatable, Sendable, CaseIterable {
    case none
    case low
    case medium
    case high
    case veryHigh = "very_high"
    case unknown

    init(rawCorpus: String) {
        let key = rawCorpus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "none": self = .none
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "very_high", "veryhigh": self = .veryHigh
        default: self = .unknown
        }
    }

    var level: Int? {
        switch self {
        case .none: 0
        case .low: 1
        case .medium: 2
        case .high: 3
        case .veryHigh: 4
        case .unknown: nil
        }
    }

    static func classify(drawersPerLfm value: Double?) -> EquipmentDensity {
        guard let value, value >= 0 else { return .unknown }
        if value == 0 { return .none }
        if value <= 1.5 { return .low }
        if value <= 3.0 { return .medium }
        if value <= 4.5 { return .high }
        return .veryHigh
    }

    static func classifyQuery(drawerCount: Int, lengthM: Double?) -> EquipmentDensity {
        guard drawerCount > 0, let lengthM, lengthM > 0 else { return .unknown }
        return classify(drawersPerLfm: Double(drawerCount) / lengthM)
    }

    func isHardIncompatible(with other: EquipmentDensity) -> Bool {
        guard let selfLevel = level, let otherLevel = other.level else { return false }
        return abs(selfLevel - otherLevel) >= 2
    }
}

enum FrontExecution: String, CaseIterable, Sendable {
    case melamine = "melamin"
    case linoleum
    case veneer = "furnier"
    case lacquer = "lack"
    case stainless = "edelstahl"
    case solidWood = "massivholz"
    case glass = "glas"
    case unknown = "unbekannt"

    var variableMultiplier: Double {
        switch self {
        case .melamine: 0.85
        case .linoleum: 1.00
        case .veneer: 1.05
        case .glass: 1.25
        case .solidWood: 1.30
        case .lacquer: 1.05
        case .stainless: 1.45
        case .unknown: 1.00
        }
    }

    var isThinPrior: Bool {
        switch self {
        case .stainless, .lacquer, .glass, .solidWood: true
        default: false
        }
    }

    var localizationKey: String { "calc.front.\(rawValue)" }

    static func infer(from materials: Set<String>) -> FrontExecution {
        let lowered = Set(materials.map { $0.lowercased() })
        func any(_ needles: String...) -> Bool { needles.contains { needle in lowered.contains { $0.contains(needle) } } }
        if any("edelstahl", "stainless", "v2a", "1.4301") { return .stainless }
        if any("linoleum", "valchromat", "forbo", "forescolor", "fenix") { return .linoleum }
        if any("lack", "hochglanz", "lackiert") { return .lacquer }
        if any("furnier", "eiche", "nussbaum", "esche", "ahorn", "walnuss") { return .veneer }
        if any("massivholz", "massiv") { return .solidWood }
        if any("glas", "riffelglas", "bronzeglas") { return .glass }
        if any("dekorspan", "melamin", "egger", "spanplatte", "pfleiderer", "mdf") { return .melamine }
        return .unknown
    }
}

enum ComponentClass: String, CaseIterable, Equatable, Hashable, Sendable {
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
}

struct ComponentRequirement: Equatable, Identifiable, Sendable {
    let id: UUID
    let component: EstimateComponent
    let allowedComponentClasses: Set<ComponentClass>
    let forbiddenComponentClasses: Set<ComponentClass>
    let minEvidenceCount: Int
    let maxScaleFactor: Double

    init(id: UUID = UUID(), component: EstimateComponent, allowedComponentClasses: Set<ComponentClass>, forbiddenComponentClasses: Set<ComponentClass>, minEvidenceCount: Int, maxScaleFactor: Double) {
        self.id = id
        self.component = component
        self.allowedComponentClasses = allowedComponentClasses
        self.forbiddenComponentClasses = forbiddenComponentClasses
        self.minEvidenceCount = minEvidenceCount
        self.maxScaleFactor = maxScaleFactor
    }
}

enum ComponentType: String, CaseIterable, Equatable, Sendable {
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

    var localizationKey: String { "calc.componentType.\(rawValue)" }
}
