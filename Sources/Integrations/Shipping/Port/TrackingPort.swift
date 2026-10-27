public protocol TrackingPort: Sendable {
    func track(_ shipment: Shipment) async throws -> Shipment
}
