public protocol EstimationPort: AnyObject, Sendable {
    func estimate(projectID: String?, text: String, override: EstimateOverride) async throws -> CostEstimate
}

public protocol AnchorRowsPort: Sendable {
    func fetchAnchorRows() async throws -> [[String: String]]
}

public protocol ArticlePricePort: Sendable {
    func purchaseNet(matching term: String) async -> Double?
}

public protocol CarcassParameterPort: Sendable {
    func parameters() async -> CarcassParameters?
}

protocol FactorPort: Sendable {
    func activeFactors() throws -> [ActiveFactor]
}

public protocol PriceAnchorPort: Sendable {
    func activeAnchors() throws -> [CandidateReleaseDecision]
}
