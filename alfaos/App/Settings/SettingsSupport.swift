import AppKit
import Hub
import ShellCore
import Observation
import SwiftUI

private struct SettingsKeychainKey: EnvironmentKey {
    static let defaultValue: any KeychainPort = KeychainAdapter()
}

extension EnvironmentValues {
    var settingsKeychain: any KeychainPort {
        get { self[SettingsKeychainKey.self] }
        set { self[SettingsKeychainKey.self] = newValue }
    }
}

enum SettingsShared {
    @MainActor static let board = SettingsBoard()
}

extension LinkState {
    var service: ServiceState {
        switch self {
        case .connected: .connected
        case .stored: .stored
        case .connecting: .connecting
        case .working: .working
        case .notConnected: .notConnected
        case .failed: .failed
        case .unreadable: .unreadable
        case .orphaned: .orphaned
        }
    }
}

enum SettingsFormat {
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de")
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: String(localized: String.LocalizationValue(key)), arguments: arguments)
    }

    static func initial(_ text: String) -> String {
        text.first.map { String($0) } ?? ""
    }
}
