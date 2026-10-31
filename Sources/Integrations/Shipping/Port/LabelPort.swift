protocol LabelPort: Sendable {
    func createLabel(_ order: LabelOrder) async throws -> LabelResult
}

public protocol TrackingPort: Sendable {
    func track(_ shipment: Shipment) async throws -> Shipment
}
