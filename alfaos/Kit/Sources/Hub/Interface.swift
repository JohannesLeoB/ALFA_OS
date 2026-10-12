import Foundation

@MainActor
public protocol HubAccess: AnyObject {
    func stock<T: Record>(_ kind: DataKind, as type: T.Type) -> Stock<T>
    func port<P>(_ port: P.Type, for inlet: Inlet.ID) throws(HubError) -> P
    func inlets(for capability: Capability) -> [Inlet]
    func write(_ order: WriteOrder) async throws(HubError)
    var events: AsyncStream<HubEvent> { get }
}

@MainActor
public protocol HubSetup: AnyObject {
    var inlets: [Inlet] { get }
    var offers: [Offer] { get }
    func add(_ offer: Offer, input: Input) async throws(SetupError) -> Inlet
    func probe(_ inlet: Inlet.ID) async throws(SetupError) -> ProbeResult
    func remove(_ inlet: Inlet.ID) async throws
}

extension HubSetup {
    public func add(_ offer: Offer) async throws(SetupError) -> Inlet {
        try await add(offer, input: .none)
    }
}

@MainActor
public protocol HubRules: AnyObject {
    func cadence(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence
    func setCadence(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence)
    func truth(_ kind: DataKind) -> Inlet.ID?
    func setTruth(_ kind: DataKind, _ inlet: Inlet.ID)
    func cost(_ inlet: Inlet.ID, _ period: Period) -> Cost
    func limit(_ capability: Capability) -> Int
    func setLimit(_ capability: Capability, _ value: Int)
    func may(_ person: Person.ID, _ right: Right) -> Bool
    func setRole(_ person: Person.ID, _ role: Role)
    func lock(_ inlet: Inlet.ID, _ right: Right, _ rule: LockRule)
    var queue: [SyncJob] { get }
}

public struct Hub {
    public let access: any HubAccess
    public let setup: any HubSetup
    public let rules: any HubRules

    public init(access: any HubAccess, setup: any HubSetup, rules: any HubRules) {
        self.access = access
        self.setup = setup
        self.rules = rules
    }
}

public enum StockState: Equatable, Sendable {
    case empty
    case loading
    case current(since: Date)
    case disturbed(Hint)
}

@MainActor
protocol StockFeed: AnyObject {
    func begin()
    func end()
    func apply(inlet: Inlet.ID, records: [any Record], at: Date)
    func drop(inlet: Inlet.ID)
    func disturb(_ hint: Hint)
}

@MainActor @Observable
public final class Stock<T: Record>: StockFeed {
    public private(set) var items: [T] = []
    public private(set) var state: StockState = .empty

    @ObservationIgnored private var refresher: (@MainActor () async -> Void)?
    @ObservationIgnored private var before: StockState?

    init(refresher: @escaping @MainActor () async -> Void) {
        self.refresher = refresher
    }

    public func refresh() async {
        await refresher?()
    }

    func begin() {
        before = state
        state = .loading
    }

    func end() {
        if state == .loading, let before { state = before }
        before = nil
    }

    func apply(inlet: Inlet.ID, records: [any Record], at: Date) {
        items = items.filter { $0.inlet != inlet } + records.compactMap { $0 as? T }
        state = .current(since: at)
    }

    func drop(inlet: Inlet.ID) {
        items = items.filter { $0.inlet != inlet }
        if items.isEmpty, case .current = state { state = .empty }
    }

    func disturb(_ hint: Hint) {
        state = .disturbed(hint)
    }
}
