import Foundation
import Synchronization

enum SetupEngine {
    static func newInlet(id: String, offer: Offer) -> Inlet {
        Inlet(id: id, provider: offer.provider, capabilities: offer.capabilities, owner: offer.owner, title: offer.title)
    }

    static func existing(offer: Offer, account: String, in inlets: [Inlet]) -> Inlet? {
        let address = normalized(account)
        return inlets.first { inlet in
            guard normalized(inlet.account) == address else { return false }
            if offer.capabilities.contains(.mail), inlet.capabilities.contains(.mail) { return true }
            return inlet.provider == offer.provider
        }
    }

    static func normalized(_ account: String) -> String {
        account.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func differs(_ expected: String, from account: String) -> Bool {
        let wanted = normalized(expected)
        return !wanted.isEmpty && wanted != normalized(account)
    }

    static func sorted(_ grant: Grant) -> [(key: String, value: String)] {
        grant.values.sorted { $0.key < $1.key }
    }

    static func keychainFailure(_ error: any Error) -> SetupFailure {
        if case KeychainFailure.status(let status) = error { return .keychain(status) }
        return .keychain(-1)
    }
}

enum RenewalEngine {
    static func renewal(of id: Inlet.ID, inlets: [Inlet], offers: [Offer]) -> Renewal? {
        guard let inlet = inlets.first(where: { $0.id == id }) else { return nil }
        let matching = offers.filter { $0.provider == inlet.provider }
        guard let offer = matching.first(where: { $0.title == inlet.title }) ?? matching.first else { return nil }
        var values = offer.preset?.values ?? [:]
        if case .form(let fields) = offer.way {
            for field in fields where field.holdsAccount { values[field.id] = inlet.account }
        }
        if inlet.capabilities.contains(.mail), !inlet.account.isEmpty { values[Input.expectedAccountKey] = inlet.account }
        values[Input.renewsKey] = inlet.id
        return Renewal(offer: offer, values: values)
    }
}

public struct SignOutFailure: Equatable, Sendable {
    public let inlet: Inlet.ID
    public let reason: String
}

public enum SignOutEngine {
    @MainActor
    public static func run(setup: any SetupPort) async -> [SignOutFailure] {
        var failed: [SignOutFailure] = []
        for inlet in setup.inlets {
            do { try await setup.remove(inlet.id) } catch { failed.append(SignOutFailure(inlet: inlet.id, reason: reason(error))) }
        }
        return failed
    }

    @MainActor
    public static func retire(setup: any SetupPort) async -> [SignOutFailure] {
        var refused: [SignOutFailure] = []
        for inlet in setup.inlets {
            do { try await setup.revoke(inlet.id) } catch { refused.append(SignOutFailure(inlet: inlet.id, reason: reason(error))) }
        }
        guard refused.isEmpty else { return refused }
        return await run(setup: setup)
    }

    static func reason(_ error: any Error) -> String {
        if case KeychainFailure.status(let status) = error { return String(status) }
        let bridged = error as NSError
        return bridged.domain + " " + String(bridged.code)
    }
}

struct ProviderRouter: Sendable {
    private let providers: [String: any ProviderPort]

    init(_ providers: [any ProviderPort]) {
        var table: [String: any ProviderPort] = [:]
        for provider in providers { table[provider.id] = provider }
        self.providers = table
    }

    func provider(_ id: String) -> (any ProviderPort)? { providers[id] }

    func classify(_ error: any Error, provider id: String?) -> Classification {
        guard let id, let provider = providers[id] else { return Classification.generic(error) }
        return provider.classify(error)
    }
}

public struct PortRegistry: Sendable {
    private var specs: [PortSpec] = []

    public init() {}

    public mutating func register<P>(
        _ type: P.Type,
        capability: Capability,
        wrap: @escaping @Sendable (P, CostMeter) -> P = { port, _ in port },
        sync: (@Sendable (P, Inlet.ID, SyncReporter) async throws -> SyncOutcome)? = nil
    ) {
        let make: @Sendable (any ProviderPort, Inlet, Grant, CostMeter, GrantRenewal) throws -> Any = { provider, inlet, grant, meter, renewal in
            wrap(try provider.adapter(P.self, for: inlet, grant, renewal: renewal), meter)
        }
        let run: @Sendable (any ProviderPort, Inlet, Grant, CostMeter, GrantRenewal, SyncReporter) async throws -> SyncOutcome = {
            provider, inlet, grant, meter, renewal, reporter in
            guard let sync else { return SyncOutcome() }
            return try await sync(wrap(try provider.adapter(P.self, for: inlet, grant, renewal: renewal), meter), inlet.id, reporter)
        }
        let key = ObjectIdentifier(type)
        specs.removeAll { $0.key == key }
        specs.append(PortSpec(key: key, capability: capability, make: make, run: run))
    }

    func spec(for type: Any.Type) -> PortSpec? {
        let key = ObjectIdentifier(type)
        return specs.first { $0.key == key }
    }

    func spec(for capability: Capability) -> PortSpec? {
        specs.first { $0.capability == capability }
    }
}

struct PortSpec: Sendable {
    let key: ObjectIdentifier
    let capability: Capability
    let make: @Sendable (any ProviderPort, Inlet, Grant, CostMeter, GrantRenewal) throws -> Any
    let run: @Sendable (any ProviderPort, Inlet, Grant, CostMeter, GrantRenewal, SyncReporter) async throws -> SyncOutcome
}

enum HintEngine {
    static let transientText = "hint.provider.transient"
    static let failedText = "hint.provider.failed"
    static let timeoutText = "hint.probe.timeout"
    static let signInTimeoutText = "hint.signin.timeout"
    static let unknownProviderText = "hint.provider.unknown"
    static let unknownInletText = "hint.inlet.unknown"
    static let unknownPortText = "hint.port.unknown"
    static let unreadableText = "hint.keychain.unreadable"
    static let unwritableText = "hint.keychain.unwritable"
    static let keyFieldsInvalidText = "hint.key.fields.invalid"
    static let keyRejectedText = "hint.key.rejected"
    static let keyFailedText = "hint.key.failed"
    static let accountMismatchText = "hint.account.mismatch"

    static func hint(_ classification: Classification, fixIn: SettingsTarget? = nil) -> Hint {
        let text: String
        switch classification.kind {
        case .transient: text = transientText
        case .signIn: text = Hint.signInExpiredText
        case .rejected: text = failedText
        }
        return Hint(text: text, classification: classification, fixIn: fixIn)
    }
}

struct HttpStatus: Error, Equatable, Sendable {
    let code: Int

    static func of(_ error: any Error) -> HttpStatus? {
        if let status = error as? HttpStatus { return status }
        if let reporting = error as? any StatusErrorPort { return HttpStatus(code: reporting.status) }
        return nil
    }

    static func isShape(_ error: any Error) -> Bool {
        error is any ShapeErrorPort
    }

    var kind: FailureKind {
        switch code {
        case 401, 403: .signIn
        case 408, 425, 429, 500...599: .transient
        default: .rejected
        }
    }
}

enum Deadline {
    static func run<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let race = Race<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                race.install(continuation)
                let worker = Task {
                    do { race.finish(.success(try await work())) } catch { race.finish(.failure(error)) }
                }
                let timer = Task {
                    try? await Task.sleep(for: limit)
                    race.finish(.failure(DeadlineExpired()))
                }
                race.attach([worker, timer])
            }
        } onCancel: {
            race.finish(.failure(CancellationError()))
        }
    }
}

struct DeadlineExpired: Error, Equatable {}

private final class Race<T: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<T, any Error>?
        var outcome: Result<T, any Error>?
        var finished = false
        var tasks: [Task<Void, Never>] = []
    }

    private let state = Mutex(State())

    func install(_ continuation: CheckedContinuation<T, any Error>) {
        let ready: Result<T, any Error>? = state.withLock { current in
            if let outcome = current.outcome { return outcome }
            current.continuation = continuation
            return nil
        }
        if let ready { continuation.resume(with: ready) }
    }

    func attach(_ tasks: [Task<Void, Never>]) {
        let stale: Bool = state.withLock { current in
            current.tasks = tasks
            return current.finished
        }
        if stale { tasks.forEach { $0.cancel() } }
    }

    func finish(_ result: Result<T, any Error>) {
        let (waiting, running): (CheckedContinuation<T, any Error>?, [Task<Void, Never>]) = state.withLock { current in
            guard !current.finished else { return (nil, []) }
            current.finished = true
            current.outcome = result
            let waiting = current.continuation
            current.continuation = nil
            return (waiting, current.tasks)
        }
        running.forEach { $0.cancel() }
        waiting?.resume(with: result)
    }
}
