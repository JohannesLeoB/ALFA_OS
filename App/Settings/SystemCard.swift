import AppKit
import Core
import Hub
import Storage
import SwiftUI

struct SystemCard: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState

    private var version: String {
        let info = Bundle.main
        let short = info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return appearance.format("settings.system.version.format", short, build)
    }

    private var branch: String? {
        let info = Bundle.main
        guard let name = info.object(forInfoDictionaryKey: "ALFABranch") as? String, !name.isEmpty,
              let commit = info.object(forInfoDictionaryKey: "ALFACommit") as? String, !commit.isEmpty else { return nil }
        return appearance.format("settings.system.branch.format", name, commit)
    }

    private var database: String {
        guard let size = DatabaseStore.size() else { return appearance.string(SettingsKeys.valueEmpty) }
        return Format.bytes(size)
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: appearance.text(SettingsLabel.version.key)) { SettingsValue(text: Text(verbatim: version)) }
            if let branch {
                SettingsRow(label: appearance.text(SettingsLabel.branch.key)) { SettingsValue(text: Text(verbatim: branch)) }
            }
            SettingsRow(label: appearance.text(SettingsLabel.database.key)) { SettingsValue(text: Text(verbatim: database)) }
            SettingsRow(label: appearance.text(SettingsLabel.diagnosis.key), line: false) {
                TextButton(label: appearance.text("settings.system.copy")) { copy() }
            }
        }
    }

    private func copy() {
        var lines = [line(.version, version)]
        if let branch { lines.append(line(.branch, branch)) }
        lines.append(line(.database, database))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        state.notify("settings.toast.copied")
    }

    private func line(_ label: SettingsLabel, _ value: String) -> String {
        appearance.format("settings.system.line", appearance.string(label.key), value)
    }
}
