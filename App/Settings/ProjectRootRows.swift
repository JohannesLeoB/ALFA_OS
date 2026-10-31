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
    @State private var drives: [FileFolder] = []
    @State private var anchor = AnchorBox()

    var body: some View {
        Group {
            SettingsRow(label: appearance.text("settings.row.projectRoot")) {
                ChoiceButton(label: root.map { Text(verbatim: $0.name) } ?? appearance.text("settings.value.choose"),
                             entries: { driveEntries }, anchor: anchor)
            }
            if root != nil {
                SettingsRow(label: appearance.text(info.extraKey(extra))) {
                    TextButton(label: appearance.text(extra.actionKey)) { sync() }
                }
            }
        }
        .task(id: inlet.id) {
            root = context.roots.current()
            drives = (try? await port()?.drives()) ?? []
        }
    }

    private var driveEntries: [MenuEntry] {
        var result: [MenuEntry] = [.head(id: "drive.head", label: appearance.text("settings.projectRoot.drive"))]
        if drives.isEmpty {
            result.append(.row(MenuItem(id: "drive.none", label: appearance.text("settings.root.none"), action: {})))
        }
        for drive in drives {
            result.append(.row(MenuItem(id: drive.id, label: Text(verbatim: name(of: drive))) { open(drive) }))
        }
        return result
    }

    private func name(of drive: FileFolder) -> String {
        drive.id == FileFolder.ownDrive ? appearance.string("settings.root.drive") : drive.name
    }

    private func open(_ drive: FileFolder) {
        Task {
            let folders = await listing(drive.id)
            var result: [MenuEntry] = [.head(id: "root.head", label: Text(verbatim: name(of: drive)))]
            if folders.isEmpty {
                result.append(.row(MenuItem(id: "root.none", label: appearance.text("settings.root.none"), action: {})))
            }
            for folder in folders {
                result.append(.row(MenuItem(id: folder.id, label: Text(verbatim: folder.name),
                                            check: folder.id == root?.id ? appearance.text(SettingsKeys.menuCheck) : nil) {
                    choose(folder, in: drive)
                }))
            }
            anchor.showMenu(result)
        }
    }

    private func port() -> (any FilesPort)? {
        try? context.access.port((any FilesPort).self, for: inlet.id)
    }

    private func listing(_ folderID: String) async -> [FileEntry] {
        guard let all = try? await port()?.files(in: folderID) else { return [] }
        return all.filter(\.isFolder).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func choose(_ folder: FileEntry, in drive: FileFolder) {
        let label = appearance.format("settings.projectRoot.path", name(of: drive), folder.name)
        let chosen = DriveRoot(id: folder.id, name: label)
        context.roots.choose(chosen)
        root = chosen
        context.state.notify("settings.toast.rootChosen", name: label)
    }

    private func sync() {
        Task {
            switch await context.syncNow(inlet.id, .files) {
            case .finished: context.state.notify("settings.projectRoot.synced")
            case .failed: context.state.notify("settings.projectRoot.syncFailed", failed: true) { sync() }
            case .skipped: break
            }
        }
    }
}
