import Foundation

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
