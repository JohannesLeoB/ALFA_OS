import Foundation

/// Every setting of the app. The raw value is the key that the store writes.
/// Secrets (`storage == .keychain`) never reach the store; they live in the keychain.
public enum Setting: String, CaseIterable, Sendable {
    case defaultFolder = "settings.doc.defaultFolder"
    case startBehavior = "settings.start.behavior"
    case claudeAPIKey = "settings.claude.apiKey"
    case figmaToken = "settings.figma.token"
    case githubToken = "settings.github.token"
    case pinterestOAuth = "settings.pinterest.oauth"
    case iCloudSync = "settings.sync.iCloud"
    case unitDefault = "settings.unit.default"
    case gridStep = "settings.canvas.gridStep"
    case snapToSpacingTokens = "settings.snap.toSpacingTokens"
    case keysPreset = "settings.keys.preset"
    case playerMaxLive = "settings.player.maxLive"
    case cacheMaxMB = "settings.cache.maxMB"

    /// Where the value is kept.
    public var storage: SettingStorage {
        switch self {
        case .claudeAPIKey, .figmaToken, .githubToken, .pinterestOAuth: .keychain
        default: .defaults
        }
    }

    /// The default value. nil for secrets, which have no default.
    public var defaultValue: SettingValue? {
        switch self {
        case .defaultFolder: .text("Documents/ALFAcolor")
        case .startBehavior: .text(StartBehavior.window.rawValue)
        case .claudeAPIKey, .figmaToken, .githubToken, .pinterestOAuth: nil
        case .iCloudSync: .flag(false)
        case .unitDefault: .text(UnitChoice.point.rawValue)
        case .gridStep: .number(8)
        case .snapToSpacingTokens: .flag(false)
        case .keysPreset: .text(KeysPreset.inDesign.rawValue)
        case .playerMaxLive: .number(1)
        case .cacheMaxMB: .number(2048)
        }
    }

    /// Whether a value is allowed for this setting. Values outside the range fall back to the default.
    public func accepts(_ value: SettingValue) -> Bool {
        switch (self, value) {
        case (.defaultFolder, .text(let path)):
            return !path.isEmpty
        case (.startBehavior, .text(let text)):
            return StartBehavior(rawValue: text) != nil
        case (.iCloudSync, .flag), (.snapToSpacingTokens, .flag):
            return true
        case (.unitDefault, .text(let text)):
            return UnitChoice(rawValue: text) != nil
        case (.gridStep, .number(let step)):
            return step.isFinite && step >= 1 && step <= 200
        case (.keysPreset, .text(let text)):
            return KeysPreset(rawValue: text) != nil
        case (.playerMaxLive, .number(let count)):
            return count.isFinite && count >= 1 && count <= 8 && count == count.rounded()
        case (.cacheMaxMB, .number(let megabytes)):
            return megabytes.isFinite && megabytes >= 256 && megabytes <= 16384
        default:
            return false
        }
    }
}

/// Where a setting is kept.
public enum SettingStorage: Sendable, Equatable {
    case defaults
    case keychain
}

/// A value of a setting. The type follows the setting: flags, numbers and texts.
public enum SettingValue: Equatable, Sendable {
    case flag(Bool)
    case number(Double)
    case text(String)
}

/// The start of the app: an empty start window, or the last document.
public enum StartBehavior: String, CaseIterable, Sendable {
    case window
    case lastDocument
}

/// The unit of the position fields. The raw values are the names the settings file uses.
public enum UnitChoice: String, CaseIterable, Codable, Sendable {
    case point = "pt"
    case pixel = "px"
    case millimetre = "mm"
}

/// The keyboard preset. Only the table of shortcuts shows it for now; switching is not built yet.
public enum KeysPreset: String, CaseIterable, Sendable {
    case macOS
    case inDesign
}
