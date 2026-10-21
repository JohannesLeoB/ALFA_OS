import Foundation
import GRDB
import Hub
import struct Hub.CompanySetup

@MainActor
public enum MailSetup {
    public static let defaultCadences: [Capability: Duration] = [.mail: .seconds(300)]

    public struct Assembly {
        public let hub: Hub
        public let engine: MailCore
        public let model: MailModel
    }

    public static func make(
        person: Person,
        company: CompanySetup,
        openBrowser: @escaping @Sendable (URL) async -> Bool,
        directory: URL,
        database: DatabaseQueue,
        keychain: any KeychainPort,
        cadence: any CadencePort,
        cost: any CostPort,
        cadences: [Capability: Duration] = MailSetup.defaultCadences,
        clock: @escaping @Sendable () -> Date = { Date() },
        defaults: UserDefaults? = nil
    ) throws -> Assembly {
        let providers = ProviderCatalog.standard(directory: directory, openBrowser: openBrowser)
        return try assemble(person: person, company: company, providers: providers, database: database,
                            keychain: keychain, cadence: cadence, cost: cost, cadences: cadences, clock: clock, defaults: defaults)
    }

    public static func live(
        person: Person,
        company: CompanySetup,
        openBrowser: @escaping @Sendable (URL) async -> Bool,
        directory: URL
    ) throws -> Assembly {
        let database = try HubDatabase.open(in: directory)
        return try make(person: person, company: company, openBrowser: openBrowser, directory: directory,
                        database: database, keychain: KeychainAdapter(), cadence: TimerCadence(),
                        cost: CountingCost(database), defaults: .standard)
    }

    static func assemble(
        person: Person,
        company: CompanySetup,
        providers: [any Provider],
        database: DatabaseQueue,
        keychain: any KeychainPort,
        cadence: any CadencePort,
        cost: any CostPort,
        cadences: [Capability: Duration],
        clock: @escaping @Sendable () -> Date,
        defaults: UserDefaults? = nil
    ) throws -> Assembly {
        var company = company
        let known = Set(company.offers.map(\.id))
        company.offers += offers(for: providers, owner: .person(person.id)).filter { !known.contains($0.id) }
        let configuration = HubConfiguration(
            person: person, company: company, providers: providers, keychain: keychain, cadence: cadence,
            cost: cost, catalog: PortCatalog.withMail.withFiles(), database: database, clock: clock
        )
        let core = try Hub.make(configuration)
        let setup = PresetSetup(base: core.setup, rules: core.rules, cadences: cadences)
        let hub = Hub(access: core.access, setup: setup, rules: core.rules)
        let engine = try MailCore(hub: hub.access, database: database)
        return Assembly(hub: hub, engine: engine, model: MailModel(engine: engine, defaults: defaults))
    }

    static func offers(for providers: [any Provider], owner: Owner) -> [Offer] {
        var result: [Offer] = []
        for provider in providers where provider.capabilities.contains(.mail) {
            let way: Way = provider.form.isEmpty ? .signIn : .form(provider.form)
            let base = "offer." + provider.id
            if provider.presets.isEmpty {
                result.append(Offer(id: base, provider: provider.id, title: base, capabilities: [.mail],
                                    owner: owner, way: way))
            } else {
                for preset in provider.presets {
                    result.append(Offer(id: base + "." + preset.id, provider: provider.id, title: preset.title,
                                        capabilities: [.mail], owner: owner, way: way, preset: preset))
                }
            }
        }
        return result
    }
}

@MainActor
final class PresetSetup: HubSetup {
    private let base: any HubSetup
    private let rules: any HubRules
    private let cadences: [Capability: Duration]

    init(base: any HubSetup, rules: any HubRules, cadences: [Capability: Duration]) {
        self.base = base
        self.rules = rules
        self.cadences = cadences
    }

    var inlets: [Inlet] { base.inlets }
    var offers: [Offer] { base.offers }

    func add(_ offer: Offer, input: Input) async throws(SetupError) -> Inlet {
        let inlet = try await base.add(offer, input: input)
        for capability in inlet.capabilities {
            if let interval = cadences[capability] { rules.setCadence(inlet.id, capability, .every(interval)) }
        }
        return inlet
    }

    func probe(_ inlet: Inlet.ID) async throws(SetupError) -> ProbeResult {
        try await base.probe(inlet)
    }

    func remove(_ inlet: Inlet.ID) async throws {
        try await base.remove(inlet)
    }

    func health(of inlet: Inlet.ID) -> InletHealth { base.health(of: inlet) }

    func report(for inlet: Inlet.ID) -> [ReportEntry] { base.report(for: inlet) }
}
