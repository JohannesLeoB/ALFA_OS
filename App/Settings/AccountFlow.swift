import Google
import Hub
import Mail
import Observation

enum AddStep: Equatable {
    case address
    case searching
    case found(String)
    case manual
    case renewal
}

@MainActor
@Observable
final class AccountFlow {
    private(set) var step = AddStep.address
    private(set) var needsAddress = false
    private(set) var busy = false
    private(set) var failure: Hint?
    private(set) var actedOn: String?
    private(set) var checked: Inlet.ID?
    var form: Offer?
    var values: [String: String] = [:] {
        didSet {
            if oldValue[ProviderPresets.protocolField] != values[ProviderPresets.protocolField] { applyFound() }
        }
    }

    @ObservationIgnored private let setup: any SetupPort
    @ObservationIgnored private let added: @MainActor (Inlet.ID) async -> Void
    @ObservationIgnored private var running: Task<SetupFailure?, Never>?
    @ObservationIgnored private var cancelling = false
    @ObservationIgnored private let discovery: any DiscoveryPort
    @ObservationIgnored private var finding: Task<Void, Never>?
    @ObservationIgnored private var found: [[String: String]] = []
    @ObservationIgnored private var filled: [String: String] = [:]

    init(setup: any SetupPort, discovery: any DiscoveryPort = DiscoveryClient(),
         added: @escaping @MainActor (Inlet.ID) async -> Void) {
        self.setup = setup
        self.discovery = discovery
        self.added = added
    }

    func discover() {
        finding?.cancel()
        let address = values[ProviderPresets.addressField] ?? ""
        finding = Task {
            let result = await DiscoveryEngine.choices(for: address, using: discovery)
            guard !Task.isCancelled, !result.isEmpty, values[ProviderPresets.addressField] == address else { return }
            found = result
            applyFound()
        }
    }

    var offersKinds: Bool { found.count > 1 }

    func proceed() {
        let address = (values[ProviderPresets.addressField] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let domain = DiscoveryEngine.domain(of: address) else {
            needsAddress = true
            return
        }
        needsAddress = false
        failure = nil
        values[ProviderPresets.addressField] = address
        finding?.cancel()
        found = []
        if ProviderPresets.knowsServers(form?.preset?.values) {
            step = .found(domain)
            return
        }
        step = .searching
        finding = Task {
            let result = await DiscoveryEngine.choices(for: address, using: discovery)
            guard !Task.isCancelled, step == .searching, values[ProviderPresets.addressField] == address else { return }
            found = result
            applyFound()
            step = result.isEmpty ? .manual : .found(domain)
        }
    }

    func back() {
        finding?.cancel()
        failure = nil
        step = .address
    }

    private func applyFound() {
        guard let preferred = found.first else { return }
        let preset = form?.preset?.values ?? [:]
        let untouched = { (key: String) in [nil, "", preset[key], self.filled[key]].contains(self.values[key]) }
        let field = ProviderPresets.protocolField
        let choice = untouched(field) ? preferred : (found.first { $0[field] == values[field] } ?? [:])
        var next = values
        for key in ProviderPresets.incomingFields.union(choice.keys) where untouched(key) {
            next[key] = choice[key] ?? preset[key]
        }
        filled = choice
        if next != values { values = next }
    }

    func choose(_ offer: Offer, values preset: [String: String]? = nil) async {
        failure = nil
        switch offer.way {
        case .signIn:
            await add(offer, input: preset.map { .fields($0) } ?? .none)
        case .form, .key:
            form = offer
            step = preset == nil ? .address : .renewal
            values = preset ?? offer.preset?.values ?? [:]
        }
    }

    func open(_ offers: [Offer]) {
        guard let offer = offers.first else { return }
        failure = nil
        checked = nil
        step = .address
        needsAddress = false
        form = offer
        values = offer.preset?.values ?? [:]
    }

    func select(_ offer: Offer) {
        let previous = Set(form?.preset?.values.keys.map { $0 } ?? [])
        var kept = values.filter { !previous.contains($0.key) }
        for (key, value) in offer.preset?.values ?? [:] { kept[key] = value }
        failure = nil
        needsAddress = false
        form = offer
        values = kept
    }

    func perform(_ step: IntegrationStep, for id: String) {
        actedOn = id
        checked = nil
        switch step {
        case .add(let offers):
            if let offer = offers.first { Task { await choose(offer) } }
        case .renew(let inlet):
            Task { await renew(inlet) }
        case .check(let inlet):
            Task { await probe(inlet) }
        case .none:
            failure = Hint(text: "settings.setup.unavailable", detail: id == "google" ? ClientConfigStore.fileName : nil)
        }
    }

    var canCancel: Bool { running != nil }

    func cancel() {
        cancelling = true
        running?.cancel()
    }

    func renew(_ inlet: Inlet.ID) async {
        guard let renewal = setup.renewal(of: inlet) else { return }
        await choose(renewal.offer, values: renewal.values)
    }

    func add(_ offer: Offer, input: Input) async {
        guard !busy else { return }
        busy = true
        failure = nil
        checked = nil
        cancelling = false
        let work = Task { @MainActor () -> SetupFailure? in
            do throws(SetupFailure) {
                let inlet = try await self.setup.add(offer, input: input)
                await self.added(inlet.id)
                return nil
            } catch {
                return error
            }
        }
        running = work
        let outcome = await work.value
        running = nil
        if let outcome {
            failure = cancelling || outcome == .cancelled ? nil : outcome.hint
        } else {
            close()
        }
        busy = false
    }

    func probe(_ inlet: Inlet.ID) async {
        guard !busy else { return }
        busy = true
        failure = nil
        checked = nil
        do throws(SetupFailure) {
            _ = try await setup.probe(inlet)
            checked = inlet
        } catch {
            failure = error.hint
        }
        busy = false
    }

    func remove(_ inlets: [Inlet.ID]) async {
        guard !busy else { return }
        busy = true
        failure = nil
        checked = nil
        for inlet in inlets {
            do {
                try await setup.remove(inlet)
            } catch {
                failure = Hint.failed(error)
            }
        }
        busy = false
    }

    func signOut() async -> Bool {
        guard !busy else { return false }
        busy = true
        failure = nil
        let failed = await SignOutEngine.run(setup: setup)
        busy = false
        guard failed.isEmpty else {
            failure = Hint(text: SettingsKeys.failedUnknown, detail: failed.joined(separator: ", "))
            return false
        }
        return true
    }

    func close() {
        finding?.cancel()
        found = []
        filled = [:]
        form = nil
        values = [:]
        failure = nil
        step = .address
        needsAddress = false
    }
}
