import Foundation
import Storage

public struct Offer: Identifiable, Equatable, Sendable {
    public var id: String
    public var provider: String
    public var title: String
    public var capabilities: Set<Capability>
    public var owner: Owner
    public var way: Way
    public var preset: Preset?

    public init(id: String, provider: String, title: String, capabilities: Set<Capability>, owner: Owner,
                way: Way, preset: Preset? = nil) {
        self.id = id
        self.provider = provider
        self.title = title
        self.capabilities = capabilities
        self.owner = owner
        self.way = way
        self.preset = preset
    }
}

public enum Way: Equatable, Sendable {
    case signIn
    case form([Field])
    case key([Field])
}

public struct Preset: Identifiable, Equatable, Sendable {
    public typealias ID = String
    public var id: ID
    var title: String
    public var values: [Field.ID: String]

    public init(id: ID, title: String, values: [Field.ID: String]) {
        self.id = id
        self.title = title
        self.values = values
    }
}

public struct Renewal: Equatable, Sendable {
    public var offer: Offer
    public var values: [Field.ID: String]
}

public struct Field: Identifiable, Equatable, Sendable {
    public typealias ID = String
    public var id: ID
    public var title: String
    public var secret: Bool
    public var optional: Bool
    var holdsAccount: Bool

    public init(id: ID, title: String, secret: Bool = false, optional: Bool = false, holdsAccount: Bool = false) {
        self.id = id
        self.title = title
        self.secret = secret
        self.optional = optional
        self.holdsAccount = holdsAccount
    }
}

public enum Input: Equatable, Sendable {
    public static let expectedAccountKey = "expectedAccount"
    public static let renewsKey = "renews"

    case none
    case fields([Field.ID: String])

    var values: [Field.ID: String] {
        switch self {
        case .none: [:]
        case .fields(let values): values
        }
    }

    var renews: String? {
        let text = values[Self.renewsKey] ?? ""
        return text.isEmpty ? nil : text
    }

    var expectedAccount: String? {
        let text = (values[Self.expectedAccountKey] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

public struct Grant: Sendable {
    public let values: [String: String]

    public init(values: [String: String]) {
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

public struct KeyValues: Sendable {
    let values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }

    public subscript(id: String) -> String { values[id] ?? "" }
}

public struct KeySlot: Hashable, Sendable {
    var inlet: Inlet.ID
    var name: String

    public init(inlet: Inlet.ID, name: String) {
        self.inlet = inlet
        self.name = name
    }
}

public struct ClaudeKey: Equatable, Sendable {
    public static let defaultModel = "claude-sonnet-4-6"

    public var apiKey: String
    public var model: String

    public init(apiKey: String, model: String = ClaudeKey.defaultModel) {
        self.apiKey = apiKey
        self.model = model
    }
}

public struct Configuration {
    var person: Person
    var company: CompanySetup
    var providers: [any ProviderPort]
    var keychain: any KeychainPort
    var cadence: any CadencePort
    var cost: any CostPort
    var catalog: PortRegistry
    var clock: @Sendable () -> Date
    var deadlines: Deadlines
    var reportLimit: Int
    var cadences: [Capability: Cadence]

    public init(person: Person, company: CompanySetup, providers: [any ProviderPort], keychain: any KeychainPort,
                cadence: any CadencePort, cost: any CostPort, catalog: PortRegistry = PortRegistry(),
                clock: @escaping @Sendable () -> Date = { Date() }, deadlines: Deadlines = .standard,
                reportLimit: Int = 100, cadences: [Capability: Cadence] = [:]) {
        self.person = person
        self.company = company
        self.providers = providers
        self.keychain = keychain
        self.cadence = cadence
        self.cost = cost
        self.catalog = catalog
        self.clock = clock
        self.deadlines = deadlines
        self.reportLimit = max(1, reportLimit)
        self.cadences = cadences
    }
}

public struct Deadlines: Equatable, Sendable {
    var signIn: Duration
    var probe: Duration
    var watchPause: Duration
    var pushFallback: Duration

    init(signIn: Duration = .seconds(300), probe: Duration = .seconds(60), watchPause: Duration = .seconds(2),
         pushFallback: Duration = .seconds(300)) {
        self.signIn = signIn
        self.probe = probe
        self.watchPause = watchPause
        self.pushFallback = pushFallback
    }

    public static let standard = Deadlines()
}

public struct CompanySetup: Sendable {
    var offers: [Offer]

    public init(offers: [Offer] = []) {
        self.offers = offers
    }
}

public struct Connections {
    public let access: any AccessPort
    public let setup: any SetupPort
    public let rules: any RulesPort

    init(access: any AccessPort, setup: any SetupPort, rules: any RulesPort) {
        self.access = access
        self.setup = setup
        self.rules = rules
    }

    @MainActor
    public static func make(_ configuration: Configuration, database: SQLiteStore) throws -> Connections {
        var company = configuration.company
        let known = Set(company.offers.map(\.id))
        company.offers += configuration.providers.flatMap { $0.offers(personal: .person(configuration.person.id)) }
            .filter { !known.contains($0.id) }
        var resolved = configuration
        resolved.company = company
        let state = try InletsState(resolved, inlets: InletStore(database: database), settings: SettingStore(database: database))
        let setup = PresetSetup(wrapped: state, rules: state, cadences: configuration.cadences)
        return Connections(access: state, setup: setup, rules: state)
    }
}
