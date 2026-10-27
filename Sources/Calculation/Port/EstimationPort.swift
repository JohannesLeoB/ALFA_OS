public protocol EstimationPort: AnyObject, Sendable {
    func estimate(projectID: String?, text: String, override: EstimateOverride) async throws -> CostEstimate
}
