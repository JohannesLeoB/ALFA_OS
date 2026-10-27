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
