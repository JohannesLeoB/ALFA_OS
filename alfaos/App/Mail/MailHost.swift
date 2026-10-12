import AppKit
import Hub
import Mail
import Observation
import SwiftUI

@MainActor
@Observable
final class MailHost {
    enum Phase {
        case idle
        case ready(MailSetup.Assembly)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var busy = false
    private(set) var failure: Hint?
    var adding = false
    var form: Offer?
    var values: [String: String] = [:]

    var isIdle: Bool {
        if case .idle = phase { true } else { false }
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

    func choose(_ offer: Offer) async {
        failure = nil
        switch offer.way {
        case .signIn:
            await add(offer, input: .none)
        case .form, .key:
            form = offer
            values = offer.preset?.values ?? [:]
        }
    }

    func add(_ offer: Offer, input: Input) async {
        guard case .ready(let assembly) = phase, !busy else { return }
        busy = true
        failure = nil
        do throws(SetupError) {
            let inlet = try await assembly.hub.setup.add(offer, input: input)
            assembly.model.refreshAccounts()
            assembly.model.refreshCounts()
            await assembly.model.selectAccount(inlet.id)
            close()
        } catch {
            failure = error.hint
        }
        busy = false
    }

    func close() {
        adding = false
        form = nil
        values = [:]
        failure = nil
    }
}

private struct MailHostKey: EnvironmentKey {
    static let defaultValue: MailHost? = nil
}

private struct MailInboxLiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var mailHost: MailHost? {
        get { self[MailHostKey.self] }
        set { self[MailHostKey.self] = newValue }
    }

    var mailInboxLive: Bool {
        get { self[MailInboxLiveKey.self] }
        set { self[MailInboxLiveKey.self] = newValue }
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
