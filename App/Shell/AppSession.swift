import AppKit
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
    var assistantUnseen = false
    var mailboxSwitching = false
    private(set) var toastLane = LaneKind.trailing
    @ObservationIgnored private var actionLane = LaneKind.trailing
    @ObservationIgnored private var watcher: Task<Void, Never>?
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
        shelved = connectedInlets
        panes["mail"] = InboxPane(session: self)
        panes["settings"] = SettingsPane.make(assembly: assembly, desk: desk)
        for (id, pane) in panes { desk.limit(id, pane.limits) }
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
        await inbox.start()
    }

    func sync() async {
        guard !syncing else { return }
        syncing = true
        await inbox.refreshFolders()
        await inbox.loadSelection()
        syncing = false
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

struct ShellResources {
    static let directoryName = "apps"

    let directory: AppDirectory

    init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: Self.directoryName, withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        directory = try AppDirectory(data: Data(contentsOf: url))
    }
}
