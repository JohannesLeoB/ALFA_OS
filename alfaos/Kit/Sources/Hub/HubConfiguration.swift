import Foundation
import GRDB

public struct CompanySetup: Sendable {
    public var offers: [Offer]
    public var limits: [Capability: Int]

    public init(offers: [Offer] = [], limits: [Capability: Int] = [.mail: 3]) {
        self.offers = offers
        self.limits = limits
    }
}

public struct HubConfiguration {
    public var person: Person
    public var company: CompanySetup
    public var providers: [any Provider]
    public var keychain: any KeychainPort
    public var cadence: any CadencePort
    public var cost: any CostPort
    public var catalog: PortCatalog
    public var database: DatabaseQueue
    public var clock: @Sendable () -> Date

    public init(person: Person, company: CompanySetup, providers: [any Provider], keychain: any KeychainPort,
                cadence: any CadencePort, cost: any CostPort, catalog: PortCatalog = .standard,
                database: DatabaseQueue, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.person = person
        self.company = company
        self.providers = providers
        self.keychain = keychain
        self.cadence = cadence
        self.cost = cost
        self.catalog = catalog
        self.database = database
        self.clock = clock
    }
}

extension Hub {
    @MainActor
    public static func make(_ configuration: HubConfiguration) throws -> Hub {
        let core = try HubCore(configuration)
        return Hub(access: core, setup: core, rules: core)
    }
}
