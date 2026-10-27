public protocol PriceAnchorPort: Sendable {
    func activeAnchors() throws -> [CandidateReleaseDecision]
}
