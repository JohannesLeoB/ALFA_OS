import Foundation

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
