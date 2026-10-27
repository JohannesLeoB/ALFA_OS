public protocol ShipmentPort: Sendable {
    func track(number: String) async throws -> ShipmentStatus
}
