import AppKit
import Mail
import ShellCore
import SwiftUI

struct MailLaneLink: Sendable {
    var openLanes = 3
    var fold: @MainActor @Sendable (Lane) -> Void = { _ in }
    var maximized: Lane?
    var toggleMaximize: @MainActor @Sendable (Lane) -> Void = { _ in }
    var openSettings: @MainActor @Sendable () -> Void = {}
    var openService: @MainActor @Sendable (String) -> Void = { _ in }
    var blobOpen = false
}

extension MailLaneLink {
    @MainActor
    init(shell: ShellModel) {
        let open = shell.widths.all.filter { $0 > shell.geometry.laneFolded }.count
        self.init(openLanes: open, fold: { shell.toggleFold($0) }, maximized: shell.laneState(shell.currentID).maximized,
                  toggleMaximize: { shell.toggleMaximize($0) }, openSettings: { shell.select("settings") },
                  openService: { service in
                      SettingsShared.board.group = .connections
                      SettingsShared.board.open(service)
                      shell.select("settings")
                  },
                  blobOpen: shell.mode != nil)
    }
}

extension MailAction {
    var shortcut: KeyboardShortcut? {
        switch self {
        case .reply: KeyboardShortcut("r", modifiers: .command)
        case .replyAll: KeyboardShortcut("r", modifiers: [.command, .shift])
        case .forward: KeyboardShortcut("f", modifiers: [.command, .shift])
        case .saveDraft: KeyboardShortcut("s", modifiers: .command)
        case .print: KeyboardShortcut("p", modifiers: .command)
        default: nil
        }
    }
}

private struct MailLaneLinkKey: EnvironmentKey {
    static let defaultValue: MailLaneLink? = nil
}

extension EnvironmentValues {
    var mailLaneLink: MailLaneLink? {
        get { self[MailLaneLinkKey.self] }
        set { self[MailLaneLinkKey.self] = newValue }
    }
}

func words(_ key: String, _ args: CVarArg...) -> String {
    let format = String(localized: String.LocalizationValue(key))
    return args.isEmpty ? format : String(format: format, arguments: args)
}

func line(_ key: String, _ args: CVarArg...) -> Text {
    Text(verbatim: args.isEmpty ? words(key) : String(format: words(key), arguments: args))
}

extension View {
    func scrolledSignal(_ scrolled: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 0 } action: { _, now in scrolled.wrappedValue = now }
    }
}

struct SmallText: View {
    let text: Text
    var tone: KeyPath<DesignColors, RGB> = \.inkTertiary

    var body: some View {
        text
            .designText(tone, size: Design.TextSize.small)
            .lineLimit(1)
    }
}
