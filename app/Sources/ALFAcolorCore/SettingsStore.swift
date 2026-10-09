import Foundation

/// The place where the values of the settings are kept. The app uses UserDefaults; tests use `MemorySettingsBacking`.
public protocol SettingsBacking: AnyObject {
    func object(forKey key: String) -> Any?
    func setObject(_ value: Any?, forKey key: String)
}

/// Reads and writes the settings. A missing or invalid value gives the default. Secrets are never written here.
public final class SettingsStore {
    private let backing: SettingsBacking

    public init(backing: SettingsBacking) {
        self.backing = backing
    }

    /// The current value, the default when none is stored or the stored value is not allowed. nil for secrets.
    public func value(_ setting: Setting) -> SettingValue? {
        guard setting.storage == .defaults else { return nil }
        if let stored = read(setting), setting.accepts(stored) {
            return stored
        }
        return setting.defaultValue
    }

    /// Stores a value. Returns false, and writes nothing, for a secret or a value that is not allowed.
    @discardableResult
    public func set(_ value: SettingValue, for setting: Setting) -> Bool {
        guard setting.storage == .defaults, setting.accepts(value) else { return false }
        switch value {
        case .flag(let flag): backing.setObject(flag, forKey: setting.rawValue)
        case .number(let number): backing.setObject(number, forKey: setting.rawValue)
        case .text(let text): backing.setObject(text, forKey: setting.rawValue)
        }
        return true
    }

    /// Removes the stored value, so the default applies again.
    public func reset(_ setting: Setting) {
        guard setting.storage == .defaults else { return }
        backing.setObject(nil, forKey: setting.rawValue)
    }

    /// The value as a flag, the default when it has another type.
    public func flag(_ setting: Setting) -> Bool {
        if case .flag(let flag) = value(setting) { return flag }
        return false
    }

    /// The value as a number, 0 when it has another type.
    public func number(_ setting: Setting) -> Double {
        if case .number(let number) = value(setting) { return number }
        return 0
    }

    /// The value as a text, the empty text when it has another type.
    public func text(_ setting: Setting) -> String {
        if case .text(let text) = value(setting) { return text }
        return ""
    }

    /// Reads the stored value and converts it to the type of the setting. nil when it has another type.
    private func read(_ setting: Setting) -> SettingValue? {
        guard let stored = backing.object(forKey: setting.rawValue) else { return nil }
        switch setting.defaultValue {
        case .flag?:
            return (stored as? Bool).map(SettingValue.flag)
        case .number?:
            return (stored as? NSNumber).map { SettingValue.number($0.doubleValue) }
        case .text?:
            return (stored as? String).map(SettingValue.text)
        case nil:
            return nil
        }
    }
}

/// An in-memory backing. Tests use it; it never touches UserDefaults.
public final class MemorySettingsBacking: SettingsBacking {
    private var values: [String: Any] = [:]

    public init() {}

    public func object(forKey key: String) -> Any? { values[key] }

    public func setObject(_ value: Any?, forKey key: String) {
        values[key] = value
    }
}

/// The backing of the app: UserDefaults of the app.
public final class DefaultsSettingsBacking: SettingsBacking {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func object(forKey key: String) -> Any? { defaults.object(forKey: key) }

    public func setObject(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
