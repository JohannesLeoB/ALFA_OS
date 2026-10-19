import AppKit
import Hub
import ShellCore
import Observation
import SwiftUI

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

struct SettingsMenuRequest: Identifiable {
    let id = UUID()
    let anchor: CGRect
    let entries: [MenuEntry]
    var width = Design.Size.menuWidthRow
}

private struct AnchorKey: PreferenceKey {
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

@MainActor @Observable
final class SettingsMenuState {
    var request: SettingsMenuRequest?
}

private struct MenuStateKey: EnvironmentKey {
    static let defaultValue: SettingsMenuState? = nil
}

extension EnvironmentValues {
    var menuState: SettingsMenuState? {
        get { self[MenuStateKey.self] }
        set { self[MenuStateKey.self] = newValue }
    }
}

extension View {
    func anchorFrame(_ frame: Binding<CGRect>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: AnchorKey.self, value: proxy.frame(in: .named(SettingsSpace.stack)))
            }
        )
        .onPreferenceChange(AnchorKey.self) { frame.wrappedValue = $0 }
    }
}

struct SettingsMenuChoice: View {
    @Environment(\.menuState) private var menus
    @State private var frame = CGRect.zero
    let label: Text
    let entries: () -> [MenuEntry]

    var body: some View {
        ChoiceButton(label: label, action: { menus?.request = SettingsMenuRequest(anchor: frame, entries: entries(), width: Design.Size.menuWidthNarrow) }) {
            Glyph(.chevron, size: Design.Spacing.step12, stroke: SheetValues.smallIconStroke)
        }
        .anchorFrame($frame)
    }
}

struct SettingsMenuAction: View {
    @Environment(\.menuState) private var menus
    @State private var frame = CGRect.zero
    let label: Text
    var kind = TextButtonKind.neutral
    let entries: () -> [MenuEntry]

    var body: some View {
        TextButton(label: label, kind: kind) { menus?.request = SettingsMenuRequest(anchor: frame, entries: entries()) }
            .anchorFrame($frame)
    }
}

enum SettingsSpace {
    static let stack = "settingsStack"
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

    static func initials(_ text: String) -> String {
        String(text.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }
}
