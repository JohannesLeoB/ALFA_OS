public struct CompositeAnchorStore: PriceAnchorPort {
    private let primary: any PriceAnchorPort
    private let learned: any PriceAnchorPort
    private let pdfLearned: (any PriceAnchorPort)?

    public init(primary: any PriceAnchorPort, learned: any PriceAnchorPort, pdfLearned: (any PriceAnchorPort)? = nil) {
        self.primary = primary
        self.learned = learned
        self.pdfLearned = pdfLearned
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        let base = try primary.activeAnchors()
        return base + orEmpty(learned) + (pdfLearned.map(orEmpty) ?? [])
    }

    private func orEmpty(_ provider: any PriceAnchorPort) -> [CandidateReleaseDecision] {
        (try? provider.activeAnchors()) ?? []
    }
}
