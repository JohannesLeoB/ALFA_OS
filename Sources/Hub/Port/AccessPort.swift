import Foundation

@MainActor
public protocol AccessPort: AnyObject {
    func stock<T: Item>(_ kind: DataKind, as type: T.Type) -> StockState<T>
    func port<P>(_ port: P.Type, for inlet: Inlet.ID) throws(HubFailure) -> P
    func inlets(for capability: Capability) -> [Inlet]
    func configured(for capability: Capability) -> [Inlet]
    func classify(_ error: any Error, inlet: Inlet.ID) -> Classification
    func track<T>(_ inlet: Inlet.ID, _ capability: Capability, body: @MainActor (SyncReporter) async -> T) async -> T
    var events: AsyncStream<InletEvent> { get }
}

@MainActor
public protocol SetupPort: AnyObject {
    var inlets: [Inlet] { get }
    var offers: [Offer] { get }
    func add(_ offer: Offer, input: Input) async throws(SetupFailure) -> Inlet
    func probe(_ inlet: Inlet.ID) async throws(SetupFailure) -> ProbeResult
    func remove(_ inlet: Inlet.ID) async throws
    func revoke(_ inlet: Inlet.ID) async throws
    func report(for inlet: Inlet.ID) -> [ReportEntry]
    func heldSlots(of inlet: Inlet.ID) -> Set<String>
}

extension SetupPort {
    public func renewal(of id: Inlet.ID) -> Renewal? {
        RenewalEngine.renewal(of: id, inlets: inlets, offers: offers)
    }
}

@MainActor
public protocol RulesPort: AnyObject {
    func cadence(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence
    func setCadence(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence)
    var queue: [SyncJob] { get }
    func progress(_ inlet: Inlet.ID, _ capability: Capability) -> RunProgress?
    func lastSync(_ inlet: Inlet.ID, _ capability: Capability) -> Date?
    @discardableResult
    func syncNow(_ inlet: Inlet.ID, _ capability: Capability) async -> SyncReport
}

public protocol CadencePort: Sendable {
    func attach(_ runner: @escaping SyncPort)
    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence)
    @discardableResult
    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async -> SyncReport
}

public typealias SyncPort = @Sendable (Inlet.ID, Capability) async -> SyncReport

public protocol CostPort: Sendable {
    func book(_ item: CostItem)
}

public protocol KeychainPort: Sendable {
    func put(_ value: String, at slot: KeySlot) throws
    func get(_ slot: KeySlot) throws -> String?
    func delete(_ slot: KeySlot) throws
}

@MainActor
protocol StockFeedPort: AnyObject {
    func begin()
    func end()
    func apply(inlet: Inlet.ID, records: [any Item], at: Date)
    func drop(inlet: Inlet.ID)
    func disturb(_ hint: Hint)
}

public protocol ExportPort: Sendable {
    var isAvailable: Bool { get }
    func collect(at date: Date) throws(ExportFailure) -> ExportSource
    func save(_ data: Data, to url: URL) throws(ExportFailure)
}
