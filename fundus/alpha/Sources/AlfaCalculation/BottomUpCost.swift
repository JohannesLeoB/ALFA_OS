import Foundation

@inline(__always) private func dec(_ value: Double) -> Decimal {
    value.isFinite ? Decimal(value) : Decimal(0)
}

public struct BottomUpStageCost: Codable, Equatable, Sendable {
    public let stage: String
    public let minutesPerCarcase: Double
    public let ratePerHour: Decimal
    public let cost: Decimal
}

public struct BottomUpEstimate: Codable, Equatable, Sendable {
    public let laborNet: Decimal
    public let materialNet: Decimal
    public let total: Decimal
    public let carcaseEquivalents: Double
    public let frontAreaM2: Double
    public let stageBreakdown: [BottomUpStageCost]
    public let assumptions: [String]
}

public enum CostModel {
    public struct Stage: Sendable {
        public let key: String
        public let label: String
        public let ratePerHour: Decimal
        public let minutesPerCarcase: Double
    }
    public static let stages: [Stage] = [
        Stage(key: "av",       label: "AV/Aufmaß",         ratePerHour: 104, minutesPerCarcase: 60),
        Stage(key: "zuschnitt", label: "Zuschnitt",         ratePerHour: 100, minutesPerCarcase: 15),
        Stage(key: "kante",    label: "Kante",             ratePerHour: 95,  minutesPerCarcase: 30),
        Stage(key: "cnc",      label: "CNC/BHX",           ratePerHour: 115, minutesPerCarcase: 20),
        Stage(key: "bankraum", label: "Bankraum",          ratePerHour: 85,  minutesPerCarcase: 60),
        Stage(key: "lager",    label: "Lager",             ratePerHour: 85,  minutesPerCarcase: 10),
        Stage(key: "laden",    label: "Laden",             ratePerHour: 85,  minutesPerCarcase: 30),
        Stage(key: "montage",  label: "Anliefern/Montage", ratePerHour: 82,  minutesPerCarcase: 120),
    ]

    public static let carcaseWidthM = 0.6        
    public static let carcaseSurfaceM2 = 2.93    
    public static let baseFrontHeightM = 0.72    

    public static let frontReferenceLowEURperM2: Decimal = 1365
    public static let frontReferenceMedianEURperM2: Decimal = 1634
    public static let frontReferenceHighEURperM2: Decimal = 2809

    public static let dekorspanEURperM2: Decimal = Decimal(string: "9.02")!
    public static let dekorFrontEURperM2: Decimal = Decimal(string: "14.02")!   
    public static let mdfEURperM2: Decimal = Decimal(string: "16.56")!
    public static let furnierspanEURperM2: Decimal = Decimal(string: "21.90")!  
    public static let fertiglackiertEURperM2: Decimal = Decimal(string: "27.55")! 
    public static let linoleumFrontEURperM2: Decimal = Decimal(string: "45.00")! 

    public static var laborPerCarcase: Decimal {
        stages.reduce(Decimal(0)) { $0 + $1.ratePerHour * dec($1.minutesPerCarcase / 60) }
    }

    public static func frontEURperM2(materials: Set<String>) -> (price: Decimal, label: String) {
        if materials.contains("furnier") || materials.contains("eiche") || materials.contains("nussbaum")
            || materials.contains("massivholz") || materials.contains("esche") || materials.contains("ahorn") {
            return (furnierspanEURperM2, "Furnierspan")
        }
        if materials.contains("lack") || materials.contains("fenix") {
            return (fertiglackiertEURperM2, "Fertiglackiert/PM")
        }
        if materials.contains("linoleum") {
            return (linoleumFrontEURperM2, "Linoleum auf MDF")
        }
        if materials.contains("mdf") {
            return (mdfEURperM2, "MDF")
        }
        return (dekorFrontEURperM2, "Dekor")
    }
}

public struct BottomUpCostEngine {
    public init() {}

    public func estimate(components: [EstimateComponent]) -> BottomUpEstimate {
        var carcases = 0.0
        var frontArea = 0.0
        let materials = components.reduce(into: Set<String>()) { $0.formUnion($1.materials) }

        for c in components {
            switch c.componentClass {
            case .kitchenRun:
                carcases += c.quantity / CostModel.carcaseWidthM
                frontArea += c.quantity * CostModel.baseFrontHeightM
            case .baseUnit:
                let width = c.widthM ?? (c.unit == "piece" ? 0.6 : c.quantity)
                carcases += max(1.0, width / CostModel.carcaseWidthM)
                frontArea += width * CostModel.baseFrontHeightM
            case .tallCabinetBlock:
                let width = c.widthM ?? c.quantity
                let height = c.heightM ?? 2.0
                carcases += max(1.0, width / CostModel.carcaseWidthM)
                frontArea += width * height
            case .island:
                let width = c.widthM ?? (c.unit == "m2" ? max(1.2, c.quantity.squareRoot()) : c.quantity)
                carcases += (width / CostModel.carcaseWidthM) * 1.6   
                frontArea += width * 0.9 * 1.5
            default:
                continue   
            }
        }

        guard carcases > 0 else {
            return BottomUpEstimate(laborNet: 0, materialNet: 0, total: 0, carcaseEquivalents: 0,
                                    frontAreaM2: 0, stageBreakdown: [], assumptions: [])
        }

        let carcaseDecimal = dec(carcases)
        var stageBreakdown: [BottomUpStageCost] = []
        var labor = Decimal(0)
        for stage in CostModel.stages {
            let perCarcase = stage.ratePerHour * dec(stage.minutesPerCarcase / 60)
            let cost = perCarcase * carcaseDecimal
            labor += cost
            stageBreakdown.append(BottomUpStageCost(stage: stage.label, minutesPerCarcase: stage.minutesPerCarcase,
                                                    ratePerHour: stage.ratePerHour, cost: cost))
        }

        let carcaseMaterial = carcaseDecimal * dec(CostModel.carcaseSurfaceM2) * CostModel.dekorspanEURperM2
        let front = CostModel.frontEURperM2(materials: materials)
        let frontMaterial = dec(frontArea) * front.price
        let material = carcaseMaterial + frontMaterial

        let assumptions = [
            "Korpus-Äquivalent = Laufmeter / \(CostModel.carcaseWidthM) m (Referenz S600).",
            "Lohn \(money(CostModel.laborPerCarcase)) je Korpus (Stundensätze × hinterlegte Gewerkszeiten).",
            "Korpus-Material \(CostModel.carcaseSurfaceM2) m²/Korpus × Dekorspan \(money(CostModel.dekorspanEURperM2))/m².",
            "Frontmaterial: \(front.label) \(money(front.price))/m² × \(String(format: "%.1f", frontArea)) m² Frontfläche.",
            "Bodenpreis = Material + Lohn (ohne Arbeitsplatte, Geräte, Beschläge, Marge)."
        ]
        return BottomUpEstimate(laborNet: labor, materialNet: material, total: labor + material,
                                carcaseEquivalents: carcases, frontAreaM2: frontArea,
                                stageBreakdown: stageBreakdown, assumptions: assumptions)
    }

    private func money(_ d: Decimal) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0; f.locale = Locale(identifier: "de_DE")
        return (f.string(from: NSDecimalNumber(decimal: d)) ?? "\(d)") + " €"
    }
}

private func money(_ d: Decimal) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0; f.locale = Locale(identifier: "de_DE")
    return (f.string(from: NSDecimalNumber(decimal: d)) ?? "\(d)") + " €"
}
