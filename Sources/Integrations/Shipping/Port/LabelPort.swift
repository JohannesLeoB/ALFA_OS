protocol LabelPort: Sendable {
    func createLabel(_ order: LabelOrder) async throws -> LabelResult
}
