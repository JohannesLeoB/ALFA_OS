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

    var unread: Int { inbox.totalUnread }

    var syncFailed: Bool {
        switch inbox.listState {
        case .failed, .offline, .signInExpired: true
        default: false
        }
    }

    var attention: Bool { unread > 0 || syncFailed }

    var stackEmpty: Bool { panes[desk.currentID]?.stackEmpty ?? false }

    private var connectedInlets: Set<Inlet.ID> {
        Set(assembly.connections.setup.inlets.filter { $0.state.isConnected }.map(\.id))
    }

    func start() async {
        guard watcher == nil else { return }
        let access = assembly.connections.access
        watcher = Task { [weak self] in
            for await event in access.events {
                switch event {
                case .inletChanged, .inletRemoved: self?.reshelveIfChanged()
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
