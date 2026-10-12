import Foundation

public protocol CapabilityPort: Sendable {}
public protocol CalendarPort: CapabilityPort {}
public protocol ContactsPort: CapabilityPort {}
public protocol FilesPort: CapabilityPort {}
public protocol TasksPort: CapabilityPort {}
public protocol TimePort: CapabilityPort {}
public protocol DocumentsPort: CapabilityPort {}
public protocol AssistantPort: CapabilityPort {}
public protocol ShippingPort: CapabilityPort {}

public struct KeySlot: Hashable, Sendable {
    public var inlet: Inlet.ID
    public var name: String

    public init(inlet: Inlet.ID, name: String) {
        self.inlet = inlet
        self.name = name
    }
}

public struct Grant: Sendable {
    package let values: [String: String]

    package init(values: [String: String]) {
        self.values = values
    }
}

public struct GrantRenewal: Sendable {
    let onRenewed: @Sendable (Grant) -> Void
    let onFailed: @Sendable (any Error) -> Void

    public init(renewed: @escaping @Sendable (Grant) -> Void, failed: @escaping @Sendable (any Error) -> Void) {
        onRenewed = renewed
        onFailed = failed
    }

    public static let ignoring = GrantRenewal(renewed: { _ in }, failed: { _ in })

    public func renewed(_ grant: Grant) { onRenewed(grant) }
    public func failed(_ error: any Error) { onFailed(error) }
}

public struct ProbeResult: Equatable, Sendable {
    public var account: String
    public var rejection: Hint?

    public var accepted: Bool { rejection == nil }

    public init(account: String, rejection: Hint? = nil) {
        self.account = account
        self.rejection = rejection
    }
}

public enum KeychainError: Error, Equatable, Sendable {
    case status(Int32)
}

public protocol SignInPort: Sendable {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant
    func renew(_ grant: Grant) async throws -> Grant
    func signOut(_ inlet: Inlet) async throws
}

public protocol ProbePort: Sendable {
    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult
}

public typealias SyncRunner = @Sendable (Inlet.ID, Capability) async -> SyncReport

public protocol CadencePort: Sendable {
    func attach(_ runner: @escaping SyncRunner)
    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence)
    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async
    var reports: AsyncStream<SyncReport> { get }
}

public protocol CostPort: Sendable {
    func book(_ item: CostItem)
    func sum(_ inlet: Inlet.ID, _ period: Period) -> Cost
}

public protocol KeychainPort: Sendable {
    func put(_ value: String, at slot: KeySlot) throws
    func get(_ slot: KeySlot) throws -> String?
    func delete(_ slot: KeySlot) throws
}

public protocol Provider: Sendable {
    typealias ID = String
    var id: ID { get }
    var capabilities: Set<Capability> { get }
    var form: [Field] { get }
    var presets: [Preset] { get }
    var signIn: any SignInPort { get }
    var probe: any ProbePort { get }
    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P
    func classify(_ error: any Error) -> Classification
}

extension Provider {
    public func classify(_ error: any Error) -> Classification { Classification.generic(error) }
}

public struct CostMeter: Sendable {
    public let inlet: Inlet.ID
    public let capability: Capability
    let cost: any CostPort
    let clock: @Sendable () -> Date

    init(inlet: Inlet.ID, capability: Capability, cost: any CostPort, clock: @escaping @Sendable () -> Date) {
        self.inlet = inlet
        self.capability = capability
        self.cost = cost
        self.clock = clock
    }

    public func record(calls: Int = 1, bytes: Int = 0, tokens: Int = 0) {
        cost.book(CostItem(inlet: inlet, capability: capability,
                           cost: Cost(calls: calls, bytes: bytes, tokens: tokens), at: clock()))
    }
}

public struct PortSpec: Sendable {
    public let capability: Capability
    let make: @Sendable (any Provider, Inlet, Grant, CostMeter, GrantRenewal) throws -> Any
    let run: @Sendable (any Provider, Inlet, Grant, CostMeter, GrantRenewal) async throws -> SyncOutcome
}

public struct PortCatalog: Sendable {
    private var specs: [ObjectIdentifier: PortSpec] = [:]

    public init() {}

    public mutating func register<P>(
        _ type: P.Type,
        capability: Capability,
        wrap: @escaping @Sendable (P, CostMeter) -> P = { port, _ in port },
        sync: (@Sendable (P, Inlet.ID) async throws -> SyncOutcome)? = nil
    ) {
        let make: @Sendable (any Provider, Inlet, Grant, CostMeter, GrantRenewal) throws -> Any = { provider, inlet, grant, meter, renewal in
            wrap(try provider.adapter(P.self, for: inlet, grant, renewal: renewal), meter)
        }
        let run: @Sendable (any Provider, Inlet, Grant, CostMeter, GrantRenewal) async throws -> SyncOutcome = {
            provider, inlet, grant, meter, renewal in
            guard let sync else { return SyncOutcome() }
            return try await sync(wrap(try provider.adapter(P.self, for: inlet, grant, renewal: renewal), meter), inlet.id)
        }
        specs[ObjectIdentifier(type)] = PortSpec(capability: capability, make: make, run: run)
    }

    public static var standard: PortCatalog {
        var catalog = PortCatalog()
        catalog.register(CalendarPort.self, capability: .calendar)
        catalog.register(ContactsPort.self, capability: .contacts)
        catalog.register(FilesPort.self, capability: .files)
        catalog.register(TasksPort.self, capability: .tasks)
        catalog.register(TimePort.self, capability: .time)
        catalog.register(DocumentsPort.self, capability: .documents)
        catalog.register(AssistantPort.self, capability: .assistant)
        catalog.register(ShippingPort.self, capability: .shipping)
        return catalog
    }

    func spec(for type: Any.Type) -> PortSpec? { specs[ObjectIdentifier(type)] }

    func spec(for capability: Capability) -> PortSpec? {
        specs.values.first { $0.capability == capability }
    }
}
