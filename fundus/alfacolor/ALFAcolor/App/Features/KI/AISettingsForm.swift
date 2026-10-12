import SwiftUI
import ALFAcolorCore
import AI

/// The tab KI of the settings: the key, the link to the console, and the model of each task.
/// The model list comes from the platform; without a key only the default and the stored models show.
struct AISettingsForm: View {
    @Environment(\.openURL) private var openURL

    private let settings = AppSettings.shared.store
    @State private var keyText = ""
    @State private var hasKey = AssistantStore.shared.hasKey
    @State private var checking = false
    @State private var notice: AssistantNotice?
    @State private var models: [AIModelInfo] = []
    @State private var chosen: [Setting: String] = [:]

    var body: some View {
        Form {
            Section("ki.key.section") {
                SecureField("ki.key.field", text: $keyText)
                HStack {
                    Button("ki.key.save") { save() }
                        .disabled(keyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("ki.key.check") { check() }
                        .disabled(!hasKey || checking)
                    Button("ki.key.remove") { remove() }
                        .disabled(!hasKey)
                }
                Text(hasKey ? "ki.key.stored" : "ki.key.none")
                    .foregroundStyle(.secondary)
                if let notice {
                    Text(LocalizedStringKey(notice.textKey))
                        .foregroundStyle(.secondary)
                    if notice.action == .openConsole {
                        Button("ki.button.openConsole") { openConsole() }
                    }
                }
            }
            Section {
                Button("ki.console.link") { openConsole() }
                Text("ki.console.hint")
                    .foregroundStyle(.secondary)
            }
            Section("ki.models.section") {
                ForEach(AssistantSettings.modelSettings, id: \.setting) { entry in
                    modelPicker(entry.setting)
                }
            }
        }
        .formStyle(.grouped)
        .task { await reload() }
    }

    /// The picker of one task. The first entry is the default; the stored name is kept even when the list lacks it.
    private func modelPicker(_ setting: Setting) -> some View {
        let current = chosen[setting] ?? ""
        return Picker(selection: Binding(
            get: { current },
            set: { value in
                chosen[setting] = value
                settings.set(.text(value), for: setting)
            }
        )) {
            Text("ki.models.default").tag("")
            ForEach(options(keeping: current), id: \.id) { model in
                Text(verbatim: model.displayName).tag(model.id)
            }
        } label: {
            Text(LocalizedStringKey(setting.rawValue))
        }
    }

    private func options(keeping current: String) -> [AIModelInfo] {
        var list = models
        if !current.isEmpty, !list.contains(where: { $0.id == current }) {
            list.append(AIModelInfo(id: current, displayName: current))
        }
        return list
    }

    // MARK: Actions

    private func save() {
        do {
            try AssistantStore.shared.saveKey(keyText)
            keyText = ""
            notice = nil
        } catch {
            notice = AssistantMessages.notice(for: .network("key store"))
        }
        hasKey = AssistantStore.shared.hasKey
        Task { await reload() }
    }

    private func remove() {
        try? AssistantStore.shared.removeKey()
        hasKey = AssistantStore.shared.hasKey
        notice = nil
        models = []
    }

    /// One short call to see whether the key works. The answer is not shown.
    private func check() {
        checking = true
        notice = nil
        Task {
            defer { checking = false }
            do {
                try await AssistantStore.shared.checkKey()
                notice = AssistantNotice(textKey: "ki.key.checked", action: .none)
            } catch let error as AIError {
                notice = AssistantMessages.notice(for: error)
            } catch {
                notice = AssistantMessages.notice(for: .network("check"))
            }
        }
    }

    private func openConsole() {
        if let url = AssistantStore.consoleURL {
            openURL(url)
        }
    }

    /// Reads the stored models and the list of the platform. Without a key or a connection the list stays short.
    private func reload() async {
        chosen = Dictionary(uniqueKeysWithValues: AssistantSettings.modelSettings.map {
            ($0.setting, settings.text($0.setting))
        })
        models = (try? await AssistantStore.shared.listModels()) ?? []
    }
}
