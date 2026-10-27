import Foundation

struct BottomUpCostEngine: Sendable {
    func estimate(components: [EstimateComponent]) -> BottomUpEstimate {
        var carcasses = 0.0
        var frontArea = 0.0
        let materials = components.reduce(into: Set<String>()) { $0.formUnion($1.materials) }

        for component in components {
            switch component.componentClass {
            case .kitchenRun:
                carcasses += component.quantity / CostModel.carcassWidthM
                frontArea += component.quantity * CostModel.baseFrontHeightM
            case .baseUnit:
                let width = component.widthM ?? (component.unit == "piece" ? 0.6 : component.quantity)
                carcasses += max(1.0, width / CostModel.carcassWidthM)
                frontArea += width * CostModel.baseFrontHeightM
            case .tallCabinetBlock:
                let width = component.widthM ?? component.quantity
                let height = component.heightM ?? 2.0
                carcasses += max(1.0, width / CostModel.carcassWidthM)
                frontArea += width * height
            case .island:
                let width = component.widthM ?? (component.unit == "m2" ? max(1.2, component.quantity.squareRoot()) : component.quantity)
                carcasses += (width / CostModel.carcassWidthM) * 1.6
                frontArea += width * 0.9 * 1.5
            default:
                continue
            }
        }

        guard carcasses > 0 else {
            return BottomUpEstimate(laborNet: 0, materialNet: 0, total: 0, carcassEquivalents: 0,
                                    frontAreaM2: 0, stageBreakdown: [], assumptions: [])
        }

        let carcassDecimal = Decimal(finite: carcasses)
        var stageBreakdown: [StageCost] = []
        var labor = Decimal(0)
        for stage in CostModel.stages {
            let perCarcass = stage.ratePerHour * Decimal(finite: stage.minutesPerCarcass / 60)
            let cost = perCarcass * carcassDecimal
            labor += cost
            stageBreakdown.append(StageCost(stage: stage.key, minutesPerCarcass: stage.minutesPerCarcass,
                                            ratePerHour: stage.ratePerHour, cost: cost))
        }

        let carcassMaterial = carcassDecimal * Decimal(finite: CostModel.carcassSurfaceM2) * CostModel.decorBoardPerM2
        let front = CostModel.frontPrice(materials: materials)
        let frontMaterial = Decimal(finite: frontArea) * front.price
        let material = carcassMaterial + frontMaterial

        let assumptions = [
            Notice("calc.bottomUp.carcassEquivalent", [String(CostModel.carcassWidthM)]),
            Notice("calc.bottomUp.labor", [Notice.amount(CostModel.laborPerCarcass)]),
            Notice("calc.bottomUp.carcassMaterial", [String(CostModel.carcassSurfaceM2), Notice.amount(CostModel.decorBoardPerM2)]),
            Notice("calc.bottomUp.front", [front.materialKey, Notice.amount(front.price), Notice.fixed(frontArea, digits: 1)]),
            Notice("calc.bottomUp.floor"),
        ]
        return BottomUpEstimate(laborNet: labor, materialNet: material, total: labor + material,
                                carcassEquivalents: carcasses, frontAreaM2: frontArea,
                                stageBreakdown: stageBreakdown, assumptions: assumptions)
    }
}
