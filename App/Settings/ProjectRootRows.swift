import Google
import Hub
import SwiftUI

struct ProjectRootRows: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    let info: IntegrationInfo
    let extra: IntegrationExtra
    let inlet: Inlet
    @State private var root: DriveRoot?
    @State private var folders: [FileEntry] = []

    var body: some View {
        Group {
            SettingsRow(label: appearance.text("settings.row.projectRoot")) {
                ChoiceButton(label: root.map { Text(verbatim: $0.name) } ?? appearance.text("settings.value.choose")) { entries }
            }
            if root != nil {
                SettingsRow(label: appearance.text(info.extraKey(extra))) {
                    TextButton(label: appearance.text(extra.actionKey)) { sync() }
                }
            }
        }
        .task(id: inlet.id) {
            root = context.roots.current()
            folders = await listing()
        }
    }

    private var entries: [MenuEntry] {
        var result: [MenuEntry] = [.head(id: "root.head", label: appearance.text("settings.root.drive"))]
        if folders.isEmpty {
            result.append(.row(MenuItem(id: "root.none", label: appearance.text("settings.root.none"), action: {})))
        }
        for folder in folders {
            result.append(.row(MenuItem(id: folder.id, label: Text(verbatim: folder.name),
                                        check: folder.id == root?.id ? appearance.text(SettingsKeys.menuCheck) : nil) {
                choose(folder)
            }))
        }
        return result
    }

    private func listing() async -> [FileEntry] {
        guard let port = try? context.access.port((any FilesPort).self, for: inlet.id),
              let all = try? await port.files(in: "root") else { return [] }
        return all.filter(\.isFolder).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func choose(_ folder: FileEntry) {
        let chosen = DriveRoot(id: folder.id, name: folder.name)
        context.roots.choose(chosen)
        root = chosen
        context.state.notify("settings.toast.rootChosen", name: folder.name)
    }

    private func sync() {
        Task {
            context.state.notify(await context.syncNow(inlet.id, .files) ? "settings.toast.driveSynced" : "settings.toast.syncFailed")
        }
    }
}
