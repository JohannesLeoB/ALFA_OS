import Foundation

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
