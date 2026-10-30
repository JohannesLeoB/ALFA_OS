import Google
import Hub
import Observation

@MainActor
@Observable
final class AccountFlow {
    private(set) var busy = false
    private(set) var failure: Hint?
    private(set) var actedOn: String?
    private(set) var checked: Inlet.ID?
    var form: Offer?
    var values: [String: String] = [:]

    @ObservationIgnored private let setup: any SetupPort
    @ObservationIgnored private let added: @MainActor (Inlet.ID) async -> Void
    @ObservationIgnored private var running: Task<SetupFailure?, Never>?
    @ObservationIgnored private var cancelling = false

    init(setup: any SetupPort, added: @escaping @MainActor (Inlet.ID) async -> Void) {
        self.setup = setup
        self.added = added
    }

    func choose(_ offer: Offer, values preset: [String: String]? = nil) async {
        failure = nil
        switch offer.way {
        case .signIn:
            await add(offer, input: preset.map { .fields($0) } ?? .none)
        case .form, .key:
            form = offer
            values = preset ?? offer.preset?.values ?? [:]
        }
    }

    func open(_ offers: [Offer]) {
        guard let offer = offers.first else { return }
        failure = nil
        checked = nil
        form = offer
        values = offer.preset?.values ?? [:]
    }

    func select(_ offer: Offer) {
        let previous = Set(form?.preset?.values.keys.map { $0 } ?? [])
        var kept = values.filter { !previous.contains($0.key) }
        for (key, value) in offer.preset?.values ?? [:] { kept[key] = value }
        failure = nil
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
        form = nil
        values = [:]
        failure = nil
    }
}
