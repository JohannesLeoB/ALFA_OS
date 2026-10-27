public protocol ProviderPort: Sendable {
    typealias ID = String
    var id: ID { get }
    var capabilities: Set<Capability> { get }
    var form: [Field] { get }
    var presets: [Preset] { get }
    var signIn: any SignInPort { get }
    var probe: any ProbePort { get }
    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P
    func classify(_ error: any Error) -> Classification
    func offers(personal: Owner) -> [Offer]
}

extension ProviderPort {
    func classify(_ error: any Error) -> Classification { Classification.generic(error) }

    public func offers(personal: Owner) -> [Offer] {
        guard capabilities.contains(.mail) else { return [] }
        let way: Way = form.isEmpty ? .signIn : .form(form)
        let prefix = "offer." + id
        guard !presets.isEmpty else {
            return [Offer(id: prefix, provider: id, title: prefix, capabilities: [.mail], owner: personal, way: way)]
        }
        return presets.map { preset in
            Offer(id: prefix + "." + preset.id, provider: id, title: preset.title, capabilities: [.mail],
                  owner: personal, way: way, preset: preset)
        }
    }
}
