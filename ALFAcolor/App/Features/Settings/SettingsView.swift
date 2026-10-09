import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel
import Geometry

/// The settings window: one tab per area. Tabs whose function is not built yet are dimmed and say when they follow.
struct SettingsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("settings.tab.general", systemImage: "gearshape") }
            PlacesSettings()
                .tabItem { Label("settings.tab.places", systemImage: "folder") }
            AccountSettings()
                .tabItem { Label("settings.tab.accounts", systemImage: "person.crop.circle") }
            SyncSettings()
                .tabItem { Label("settings.tab.sync", systemImage: "icloud") }
            UnitSettings()
                .tabItem { Label("settings.tab.units", systemImage: "ruler") }
            ToolSettings()
                .tabItem { Label("settings.tab.tools", systemImage: "wrench.and.screwdriver") }
            AISettings()
                .tabItem { Label("settings.tab.ai", systemImage: "sparkles") }
            KeySettings()
                .tabItem { Label("settings.tab.keys", systemImage: "keyboard") }
            AdvancedSettings()
                .tabItem { Label("settings.tab.advanced", systemImage: "slider.horizontal.3") }
        }
        .themeText(theme.text(.body))
    }
}

/// A row that is dimmed and says when its function follows.
private struct LaterRow: View {
    let title: LocalizedStringKey
    let note: LocalizedStringKey

    var body: some View {
        LabeledContent(title) {
            Text(note).foregroundStyle(.secondary)
        }
        .disabled(true)
    }
}

private struct GeneralSettings: View {
    var body: some View {
        Form {
            LaterRow(title: "settings.general.folder", note: "settings.note.notYet")
            LaterRow(title: "settings.general.start", note: "settings.note.notYet")
        }
        .formStyle(.grouped)
    }
}

private struct AccountSettings: View {
    var body: some View {
        Form {
            // The key cannot be entered yet: the keychain flow comes with the account work.
            LabeledContent("settings.accounts.claudeKey") {
                SecureField("settings.accounts.claudeKey", text: .constant(""))
                    .disabled(true)
            }
            Text("settings.later.account").foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct SyncSettings: View {
    var body: some View {
        Form {
            Toggle("settings.sync.icloud", isOn: .constant(false)).disabled(true)
            Text("settings.later.sync").foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct AISettings: View {
    var body: some View {
        AISettingsForm()
    }
}

/// The unit and the grid step. The grid step is read at the start of a window.
private struct UnitSettings: View {
    private let store = AppSettings.shared.store
    @State private var unit = UnitChoice(AppSettings.shared.lengthUnit)
    @State private var gridStep = AppSettings.shared.gridStep

    var body: some View {
        Form {
            Picker("settings.units.default", selection: $unit) {
                ForEach(UnitChoice.allCases, id: \.self) { choice in
                    Text(LocalizedStringKey(LengthUnit(choice).symbolKey)).tag(choice)
                }
            }
            .onChange(of: unit) { _, new in
                AppSettings.shared.save(lengthUnit: LengthUnit(new))
            }
            Stepper(value: $gridStep, in: 1...200, step: 1) {
                LabeledContent("settings.units.gridStep") { Text(verbatim: "\(gridStep.clampedInt)") }
            }
            .onChange(of: gridStep) { _, new in
                store.set(.number(new), for: .gridStep)
            }
            Text("settings.note.restart").foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct ToolSettings: View {
    var body: some View {
        Form {
            // The tool options are not saved yet, so there is nothing to reset.
            Button("settings.tools.reset") {}.disabled(true)
            Text("settings.tools.note").foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct KeySettings: View {
    var body: some View {
        // The table of the shortcuts only. Switching the preset is not built.
        ShortcutTableView()
    }
}

/// The advanced settings. Player count is read at the start; the cache limit is not built yet.
private struct AdvancedSettings: View {
    private let store = AppSettings.shared.store
    @State private var players = AppSettings.shared.store.number(.playerMaxLive).clampedInt

    var body: some View {
        Form {
            Stepper(value: $players, in: 1...8) {
                LabeledContent("settings.advanced.players") { Text(verbatim: "\(players)") }
            }
            .onChange(of: players) { _, new in
                store.set(.number(Double(new)), for: .playerMaxLive)
            }
            LabeledContent("settings.advanced.cache") {
                Text("settings.note.notYet").foregroundStyle(.secondary)
            }
            .disabled(true)
            Text("settings.note.restart").foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
