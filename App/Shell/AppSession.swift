import AppKit
import Assistant
import Core
import Foundation
import Hub
import Mail
import Observation
import Shell
import SwiftUI

@MainActor
@Observable
final class AppSession {
    let assembly: Assembly
    let desk: DeskState
    var panes: [String: any Pane] = [:]
    private(set) var syncing = false
    private(set) var booted = false
    var assistantUnseen = false
    var mailboxSwitching = false
    private(set) var toastLane = LaneKind.trailing
    @ObservationIgnored private var actionLane = LaneKind.trailing
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private var arrivals: Task<Void, Never>?
    let attention: any AttentionPort = AttentionClient()
    let lock: LockState
    let shield: WindowShield
    @ObservationIgnored private var shelved: Set<Inlet.ID> = []

    init(assembly: Assembly, directory: AppDirectory) {
        self.assembly = assembly
        let store = ShellStore()
        let measure = Measure()
        let desk = DeskState(
            directory: directory, measure: measure, window: measure.windowMin, snapshot: store.load(),
            startID: assembly.settings.destination.appID)
        desk.onChange = { store.save($0) }
        self.desk = desk
        lock = LockState(port: UnlockClient(), on: assembly.settings.lockOn, pause: Self.pause(assembly.settings.lockDelay),
                         reason: String(localized: String.LocalizationValue("shell.lock.reason")),
                         resigned: NSApplication.didResignActiveNotification, became: NSApplication.didBecomeActiveNotification)
        shield = WindowShield(lock: lock)
        shelved = connectedInlets
        panes["mail"] = InboxPane(session: self)
        panes["settings"] = SettingsPane.make(assembly: assembly, desk: desk)
        for (id, pane) in panes { desk.limit(id, pane.limits) }
        lock.launch()
    }

    static func live() throws -> AppSession {
        do {
            let assembly = try Assembly(openBrowser: { url in await MainActor.run { NSWorkspace.shared.open(url) } })
            return AppSession(assembly: assembly, directory: try ShellResources(bundle: .main).directory)
        } catch {
            Log.lifecycle.error("\(String(describing: error))")
            throw error
        }
    }

    var settings: SettingsState { assembly.settings }

    var inbox: InboxState { assembly.inbox }

    var syncFailed: Bool {
        switch inbox.listState {
        case .failed, .offline, .signInExpired: true
        default: false
        }
    }

    var stackEmpty: Bool { panes[desk.currentID]?.stackEmpty ?? false }

    var stackReport: Bool? { booted ? stackEmpty : nil }

    var toast: AnyView? {
        if conversation.note != nil { return AnyView(AssistantToast(conversation: conversation)) }
        return panes[desk.currentID]?.toast
    }

    func act(at x: Double) {
        actionLane = desk.measure.lane(at: x, desk.widths)
    }

    func toastArrived(_ source: ToastSource) {
        toastLane = actionLane
        if source != .assistant, conversation.note != nil { conversation.dismiss() }
        if source != .mail, let toast = inbox.toast { inbox.dismissToast(toast.serial) }
        if source != .settings, settings.toast != nil { settings.dismissToast() }
    }

    private var connectedInlets: Set<Inlet.ID> {
        Set(assembly.connections.setup.inlets.filter { $0.state.isConnected }.map(\.id))
    }

    func start() async {
        guard watcher == nil else { return }
        let access = assembly.connections.access
        watcher = Task { [weak self] in
            for await event in access.events {
                switch event {
                case .inletChanged: self?.reshelveIfChanged()
                case .inletRemoved(let id):
                    self?.settings.forget(id)
                    self?.reshelveIfChanged()
                default: break
                }
            }
        }
        Task { [attention] in await attention.prepare() }
        arrivals = Task { [weak self] in
            guard let events = self?.assembly.mailEvents.stream else { return }
            for await event in events {
                if case .newMail(_, let count) = event { await self?.announce(arrivals: count) }
            }
        }
        await inbox.start()
        booted = true
    }

    func sync() async {
        guard !syncing else { return }
        syncing = true
        await inbox.refreshFolders()
        await inbox.loadSelection()
        await inbox.refreshOthers()
        await inbox.directory.refresh()
        syncing = false
    }

    static func pause(_ delay: LockDelay) -> LockPause {
        switch delay {
        case .immediately: .immediately
        case .minute1: .oneMinute
        case .minutes5: .fiveMinutes
        case .minutes15: .fifteenMinutes
        }
    }

    var lockInitials: String { Initials.avatar(code: settings.profile.code, name: settings.profile.name) }

    func followLockSettings() {
        lock.configure(on: settings.lockOn, pause: Self.pause(settings.lockDelay))
    }

    private func reshelveIfChanged() {
        let now = connectedInlets
        guard now != shelved else { return }
        shelved = now
        assembly.reshelve()
    }
}

private struct SessionKey: EnvironmentKey {
    static let defaultValue: AppSession? = nil
}

extension EnvironmentValues {
    var session: AppSession? {
        get { self[SessionKey.self] }
        set { self[SessionKey.self] = newValue }
    }
}

struct ResourcesMissing: Error {
    let underlying: any Error
}

struct ShellResources {
    static let directoryName = "apps"

    let directory: AppDirectory

    init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: Self.directoryName, withExtension: "json") else {
            throw ResourcesMissing(underlying: CocoaError(.fileNoSuchFile))
        }
        do {
            directory = try AppDirectory(data: Data(contentsOf: url))
        } catch {
            throw ResourcesMissing(underlying: error)
        }
    }
}

extension AppSession {
    var conversation: ChatState { assembly.conversation }

    var assistantOff: Bool { settings.privacy.assistantOff }

    var assistantFiles: Bool { !assistantOff && settings.privacy.chatFiles }

    var claudeFailed: Bool {
        let claude = assembly.connections.setup.inlets.filter { $0.provider == ClaudeCredential.provider }
        return claude.isEmpty || claude.contains { LinkState($0.state) == .failed }
    }

    var assistantHintKey: String {
        if claudeFailed { return "shell.assistantPanel.failed" }
        if panes[desk.currentID] is InboxPane && stackEmpty { return "shell.assistantPanel.noMessage" }
        return "shell.assistantPanel.idle"
    }

    var assistantOffersSettings: Bool { !(panes[desk.currentID] is SettingsPane) }

    func seeAssistant() {
        assistantUnseen = false
        conversation.load()
    }

    func askAssistant() {
        let conversation = conversation
        let choices = settings.privacy
        guard !choices.assistantOff, conversation.canSend else { return }
        let profile = settings.profile
        Task { answered(await conversation.send(choices: choices, profile: profile)) }
    }

    func retryAssistant() {
        let conversation = conversation
        let choices = settings.privacy
        guard !choices.assistantOff else { return }
        let profile = settings.profile
        Task { answered(await conversation.retry(choices: choices, profile: profile)) }
    }

    func attachToAssistant() {
        guard assistantFiles else { return }
        let panel = NSOpenPanel()
        panel.appearance = ForeignContent.panel
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let conversation = conversation
        let urls = panel.urls
        Task { await conversation.attach(urls) }
    }

    func openAssistantSettings() {
        settings.select(.protection, showing: SettingsSection.privacy.rawValue)
        desk.select("settings")
    }

    func openClaudeSettings() {
        guard let card = assembly.catalog.info(forProvider: ClaudeCredential.provider)?.id else {
            desk.select("settings")
            return
        }
        openSettingsCard(card)
    }

    private func answered(_ complete: Bool) {
        if complete && !desk.assistantOpen { assistantUnseen = true }
    }
}

extension AppSession {
    func announce(arrivals count: Int) async {
        let title = count == 1
            ? String(localized: String.LocalizationValue("shell.attention.newMail.one"))
            : String(format: String(localized: String.LocalizationValue("shell.attention.newMail.many")), String(count))
        await attention.announce(title: title)
    }
}

enum ToastSource {
    case assistant
    case mail
    case settings
}

struct HintPreference: PreferenceKey {
    struct Hint: Equatable {
        let key: String
        let point: CGPoint
    }

    static let defaultValue: Hint? = nil

    static func reduce(value: inout Hint?, nextValue: () -> Hint?) {
        value = value ?? nextValue()
    }
}
