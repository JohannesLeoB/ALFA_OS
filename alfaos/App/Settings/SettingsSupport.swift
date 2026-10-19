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

struct SettingsSymbolShape: Shape {
    let name: SymbolName

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / CGFloat(SheetValues.iconBox)
        var path = Path()
        for command in name.commands {
            switch command {
            case .move(let x, let y):
                path.move(to: CGPoint(x: rect.minX + CGFloat(x) * scale, y: rect.minY + CGFloat(y) * scale))
            case .line(let x, let y):
                path.addLine(to: CGPoint(x: rect.minX + CGFloat(x) * scale, y: rect.minY + CGFloat(y) * scale))
            case .curve(let x1, let y1, let x2, let y2, let x, let y):
                path.addCurve(
                    to: CGPoint(x: rect.minX + CGFloat(x) * scale, y: rect.minY + CGFloat(y) * scale),
                    control1: CGPoint(x: rect.minX + CGFloat(x1) * scale, y: rect.minY + CGFloat(y1) * scale),
                    control2: CGPoint(x: rect.minX + CGFloat(x2) * scale, y: rect.minY + CGFloat(y2) * scale))
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }
}

struct SettingsSymbol: View {
    let name: SymbolName
    var size = SheetValues.iconSize
    var stroke = SheetValues.iconStroke

    var body: some View {
        let side = CGFloat(size)
        let width = CGFloat(stroke * size / SheetValues.iconBox)
        SettingsSymbolShape(name: name)
            .stroke(style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
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
        ChoiceButton(label: label, action: { menus?.request = SettingsMenuRequest(anchor: frame, entries: entries()) }) {
            SettingsSymbol(name: .chevron, size: Design.Spacing.step12, stroke: SheetValues.smallIconStroke)
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
