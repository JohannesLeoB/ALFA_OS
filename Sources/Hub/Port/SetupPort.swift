@MainActor
public protocol SetupPort: AnyObject {
    var inlets: [Inlet] { get }
    var offers: [Offer] { get }
    func add(_ offer: Offer, input: Input) async throws(SetupFailure) -> Inlet
    func probe(_ inlet: Inlet.ID) async throws(SetupFailure) -> ProbeResult
    func remove(_ inlet: Inlet.ID) async throws
    func report(for inlet: Inlet.ID) -> [ReportEntry]
    func heldSlots(of inlet: Inlet.ID) -> Set<String>
}

extension SetupPort {
    public func renewal(of id: Inlet.ID) -> Renewal? {
        RenewalEngine.renewal(of: id, inlets: inlets, offers: offers)
    }
}
