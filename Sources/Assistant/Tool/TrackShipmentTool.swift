public struct TrackShipmentTool: ToolPort {
    private let shipments: any ShipmentPort

    public init(shipments: any ShipmentPort) {
        self.shipments = shipments
    }

    public var name: String { "verfolge_sendung" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("nummer", required: true)] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let number = input.text("nummer")
        guard number.isEmpty == false else { return .failure("assistant.shipment.noNumber") }
        do {
            let status = try await shipments.track(number: number)
            var text = "\(status.number): \(status.statusLabel)"
            if let detail = status.detail, detail.isEmpty == false { text += " \u{2014} \(detail)" }
            return ToolResult(.raw(text))
        } catch PortFailure.notConnected {
            return .failure("assistant.shipment.notConnected")
        } catch let failure as PortFailure {
            return ToolResult(.raw(failure.detail), isError: true)
        } catch {
            return .failure("assistant.shipment.failed", error.localizedDescription)
        }
    }
}
