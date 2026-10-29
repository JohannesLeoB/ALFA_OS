import Hub
import Observation

@MainActor
@Observable
final class AccountFlow {
    private(set) var busy = false
    private(set) var failure: Hint?
    private(set) var actedOn: String?
    var form: Offer?
    var values: [String: String] = [:]

    @ObservationIgnored private let setup: any SetupPort
    @ObservationIgnored private let added: @MainActor (Inlet.ID) async -> Void

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

    func perform(_ step: IntegrationStep, for id: String) {
        actedOn = id
        switch step {
        case .add(let offers):
            if let offer = offers.first { Task { await choose(offer) } }
        case .renew(let inlet):
            Task { await renew(inlet) }
        case .check(let inlet):
            Task { await probe(inlet) }
        case .none:
            break
        }
    }

    func renew(_ inlet: Inlet.ID) async {
        guard let renewal = setup.renewal(of: inlet) else { return }
        await choose(renewal.offer, values: renewal.values)
    }

    func add(_ offer: Offer, input: Input) async {
        guard !busy else { return }
        busy = true
        failure = nil
        do throws(SetupFailure) {
            let inlet = try await setup.add(offer, input: input)
            await added(inlet.id)
            close()
        } catch {
            failure = error.hint
        }
        busy = false
    }

    func probe(_ inlet: Inlet.ID) async {
        guard !busy else { return }
        busy = true
        failure = nil
        do throws(SetupFailure) {
            _ = try await setup.probe(inlet)
        } catch {
            failure = error.hint
        }
        busy = false
    }

    func remove(_ inlets: [Inlet.ID]) async {
        guard !busy else { return }
        busy = true
        failure = nil
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
