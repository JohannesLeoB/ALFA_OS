import AppKit
import Hub
import Mail
import Observation
import ShellCore
import SwiftUI

@MainActor
@Observable
final class AppHost {
    enum Phase {
        case idle
        case ready(MailSetup.Assembly)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var busy = false
    private(set) var failure: Hint?
    var form: Offer?
    var values: [String: String] = [:]

    private(set) var syncing = false

    var isIdle: Bool {
        if case .idle = phase { true } else { false }
    }

    var mail: MailModel? {
        if case .ready(let assembly) = phase { assembly.model } else { nil }
    }

    var stackEmpty: Bool { mail?.stackEmpty ?? true }

    var unread: Int { mail?.totalUnread ?? 0 }

    var failedInlets: Int {
        mail?.accounts.filter { if case .failed = $0.state { true } else { false } }.count ?? 0
    }

    var assistantFailed: Bool {
        guard case .ready(let assembly) = phase, let info = ServiceCatalog.info("claude") else { return false }
        return ServiceReader.read(info, setup: assembly.hub.setup, rules: assembly.hub.rules).state == .failed
    }

    var syncFailed: Bool {
        switch mail?.listState {
        case .failed, .offline, .signInExpired: true
        default: false
        }
    }

    func sync() async {
        guard let mail, !syncing else { return }
        syncing = true
        await mail.refreshFolders()
        await mail.loadSelection()
        syncing = false
    }

    func prepare() {
        guard isIdle else { return }
        do {
            let assembly = try MailSetup.live(
                person: Person(id: "local", name: "local"),
                company: CompanySetup(),
                openBrowser: { url in await MainActor.run { NSWorkspace.shared.open(url) } },
                directory: try HubDatabase.defaultDirectory()
            )
            assembly.model.prefersHTML = false
            phase = .ready(assembly)
            Task { await assembly.model.start() }
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    func choose(_ offer: Offer, values preset: [String: String]? = nil) async {
        failure = nil
        switch offer.way {
        case .signIn:
            await add(offer, input: .none)
        case .form, .key:
            form = offer
            values = preset ?? offer.preset?.values ?? [:]
        }
    }

    func renew(_ inlet: Inlet.ID) async {
        guard case .ready(let assembly) = phase, let renewal = assembly.hub.setup.renewal(of: inlet) else { return }
        await choose(renewal.offer, values: renewal.values)
    }

    func add(_ offer: Offer, input: Input) async {
        guard case .ready(let assembly) = phase, !busy else { return }
        busy = true
        failure = nil
        do throws(SetupError) {
            let inlet = try await assembly.hub.setup.add(offer, input: input)
            refresh(assembly)
            await assembly.model.selectAccount(inlet.id)
            close()
        } catch {
            failure = error.hint
        }
        busy = false
    }

    func probe(_ inlet: Inlet.ID) async {
        guard case .ready(let assembly) = phase, !busy else { return }
        busy = true
        failure = nil
        do throws(SetupError) {
            _ = try await assembly.hub.setup.probe(inlet)
        } catch {
            failure = error.hint
        }
        refresh(assembly)
        busy = false
    }

    func remove(_ inlet: Inlet.ID) async {
        guard case .ready(let assembly) = phase, !busy else { return }
        busy = true
        failure = nil
        do {
            try await assembly.hub.setup.remove(inlet)
        } catch {
            failure = Hint.failed(error)
        }
        refresh(assembly)
        busy = false
    }

    func close() {
        form = nil
        values = [:]
        failure = nil
    }

    private func refresh(_ assembly: MailSetup.Assembly) {
        assembly.model.refreshAccounts()
        assembly.model.refreshCounts()
    }
}

private struct AppHostKey: EnvironmentKey {
    static let defaultValue: AppHost? = nil
}

private struct HostLiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var appHost: AppHost? {
        get { self[AppHostKey.self] }
        set { self[AppHostKey.self] = newValue }
    }

    var hostLive: Bool {
        get { self[HostLiveKey.self] }
        set { self[HostLiveKey.self] = newValue }
    }
}

func word(_ key: String) -> Text {
    Text(LocalizedStringKey(key))
}

func hintWords(_ hint: Hint) -> some View {
    VStack(alignment: .leading) {
        word(hint.text)
        if let detail = hint.detail { Text(verbatim: detail) }
    }
}
