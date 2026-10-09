import AppKit
import ALFAcolorCore
import AppTheme
import SwiftUI

/// The places tab: the list of places with their kind, roles and state, adding, removing and showing them,
/// and the choice of the app folder. Nothing is written to a place that is not reachable.
struct PlacesSettings: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var message: LocalizedStringKey?

    private var store: PlaceStore { PlaceStore.shared }

    var body: some View {
        Form {
            if store.fileIsUnreadable {
                Text("places.error.unreadable").foregroundStyle(.secondary)
            }
            Section("places.section.list") {
                if store.places.isEmpty {
                    Text("places.empty").foregroundStyle(.secondary)
                }
                ForEach(store.places) { place in
                    placeRow(place)
                }
                Button("places.add") { addPlace() }
            }
            Section("places.appFolder.title") {
                appFolderContent
            }
            if let message {
                Text(message).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Places

    private func placeRow(_ place: Place) -> some View {
        let access = store.access(to: place)
        return VStack(alignment: .leading, spacing: theme.space(.s2)) {
            HStack {
                Text(verbatim: place.name).themeText(theme.text(.control))
                Spacer()
                Text(LocalizedStringKey(stateKey(access)))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(isReachable(access) ? theme.color(.textMuted, scheme) : theme.color(.text, scheme))
            }
            Picker("places.kind", selection: kindBinding(place)) {
                ForEach(PlaceKind.allCases, id: \.self) { kind in
                    Text(LocalizedStringKey(kindKey(kind))).tag(kind)
                }
            }
            .pickerStyle(.menu)
            HStack(spacing: theme.space(.s1)) {
                ForEach(PlaceRole.allCases, id: \.self) { role in
                    rolePill(role, place: place)
                }
            }
            HStack(spacing: theme.space(.s2)) {
                Button("places.showInFinder") { showInFinder(place) }
                    .disabled(!isReachable(access))
                if !isReachable(access) {
                    Button("places.chooseAgain") { chooseAgain(place) }
                }
                Spacer()
                Button("places.remove") { perform { try store.remove(place) } }
            }
        }
        .padding(.vertical, theme.space(.s1))
    }

    private func rolePill(_ role: PlaceRole, place: Place) -> some View {
        let on = place.roles.contains(role)
        return Button {
            var roles = place.roles
            if on { roles.remove(role) } else { roles.insert(role) }
            perform { try store.setRoles(roles, for: place) }
        } label: {
            Text(LocalizedStringKey(roleKey(role)))
                .themeText(theme.text(.caption))
                .foregroundStyle(on ? theme.color(.surface, scheme) : theme.color(.text, scheme))
                .padding(.horizontal, theme.space(.s2))
                .padding(.vertical, theme.space(.s1))
                .background(Capsule().fill(on ? theme.color(.accent, scheme) : theme.color(.surface, scheme)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func kindBinding(_ place: Place) -> Binding<PlaceKind> {
        Binding(get: { place.kind }, set: { kind in perform { try store.setKind(kind, for: place) } })
    }

    // MARK: App folder

    @ViewBuilder
    private var appFolderContent: some View {
        if let folder = store.appFolder {
            let access = store.access(to: folder)
            Text(verbatim: folder.path ?? "")
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
            if !isReachable(access) {
                Text("places.appFolder.unreachable").foregroundStyle(theme.color(.text, scheme))
            }
            Button("places.appFolder.choose") { chooseAppFolder() }
        } else {
            Text("places.appFolder.question")
            Button("places.appFolder.useDefault") { perform { try store.useDefaultAppFolder() } }
            Button("places.appFolder.choose") { chooseAppFolder() }
        }
    }

    // MARK: Actions

    private func addPlace() {
        guard let folder = chooseFolder() else { return }
        perform { try store.addFolder(folder, roles: [.workFolder]) }
    }

    private func chooseAgain(_ place: Place) {
        guard let folder = chooseFolder() else { return }
        perform { try store.relocate(place, to: folder) }
    }

    private func chooseAppFolder() {
        guard let folder = chooseFolder() else { return }
        perform { try store.useAppFolder(folder) }
    }

    private func showInFinder(_ place: Place) {
        perform {
            try store.withFolder(of: place) { url in
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    /// Shows the folder panel. Only folders can be chosen.
    private func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Runs a change and shows the reason when it is refused. A refused change changes nothing.
    private func perform(_ work: () throws -> Void) {
        do {
            try work()
            message = nil
        } catch {
            message = messageKey(for: error)
        }
    }

    private func messageKey(for error: Error) -> LocalizedStringKey {
        if let placeError = error as? PlaceError {
            switch placeError {
            case .noRole: return "places.error.noRole"
            case .tooManyPlaces: return "places.error.tooMany"
            case .emptyName, .nameTooLong: return "places.error.name"
            case .unknownPlace: return "places.error.generic"
            }
        }
        if error as? AppFolderError == .unreachable || error as? PlaceStoreError == .notReachable {
            return "places.appFolder.unreachable"
        }
        if error as? PlaceStoreError == .fileUnreadable {
            return "places.error.unreadable"
        }
        return "places.error.generic"
    }

    // MARK: Texts of the cases

    private func isReachable(_ access: PlaceAccess) -> Bool {
        if case .reachable = access { return true }
        return false
    }

    private func stateKey(_ access: PlaceAccess) -> String {
        switch access {
        case .reachable: "places.state.reachable"
        case .stale: "places.state.stale"
        case .unreachable: "places.state.unreachable"
        }
    }

    private func kindKey(_ kind: PlaceKind) -> String {
        switch kind {
        case .folder: "places.kind.folder"
        case .drive: "places.kind.drive"
        case .repo: "places.kind.repo"
        }
    }

    private func roleKey(_ role: PlaceRole) -> String {
        switch role {
        case .projectFolder: "places.role.projectFolder"
        case .workFolder: "places.role.workFolder"
        case .storage: "places.role.storage"
        case .sourceLibrary: "places.role.sourceLibrary"
        case .exportTarget: "places.role.exportTarget"
        }
    }
}
