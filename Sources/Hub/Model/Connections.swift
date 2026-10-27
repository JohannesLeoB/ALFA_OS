import Storage

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
