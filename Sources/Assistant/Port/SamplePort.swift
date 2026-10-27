protocol SamplePort: Sendable {
    func samples(projectNumber: String) async throws -> SampleListing
}
