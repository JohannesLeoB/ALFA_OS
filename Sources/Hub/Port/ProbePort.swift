public protocol ProbePort: Sendable {
    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult
}
