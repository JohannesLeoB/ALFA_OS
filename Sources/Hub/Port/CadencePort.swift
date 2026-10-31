public protocol CadencePort: Sendable {
    func attach(_ runner: @escaping SyncPort)
    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence)
    @discardableResult
    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async -> SyncReport
}
