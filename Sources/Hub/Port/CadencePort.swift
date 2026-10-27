public protocol CadencePort: Sendable {
    func attach(_ runner: @escaping SyncPort)
    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence)
    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async
}
