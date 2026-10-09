import ALFAcolorCore

/// Reads the assistant settings of the app. Each function takes the store, so the app and the tests use the same rules.
public enum AssistantSettings {
    /// The setting that holds the model of each task. A blank setting means the default model of the task.
    static let modelSettings: [(task: AITaskKind, setting: Setting)] = [
        (.codeVariant, .claudeModelCodeVariant),
        (.htmlForCSS, .claudeModelHTMLForCSS),
        (.codeFromScreenshot, .claudeModelCodeFromScreenshot),
        (.tokenNames, .claudeModelTokenNames),
        (.explain, .claudeModelExplain),
    ]

    /// The model choice of the task kinds, from the stored settings.
    public static func modelChoice(_ store: SettingsStore) -> AIModelChoice {
        var overrides: [AITaskKind: String] = [:]
        for entry in modelSettings {
            overrides[entry.task] = store.text(entry.setting)
        }
        return AIModelChoice(overrides: overrides)
    }
}
