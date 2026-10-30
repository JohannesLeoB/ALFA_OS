import Design
import Hub
import Shell
import SwiftUI

struct SettingsCommandHead: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    let readings: [IntegrationReading]
    let width: Double
    @Binding var disconnecting: String?

    private var state: SettingsState { context.state }

    private var reading: IntegrationReading? {
        state.front.flatMap { id in readings.first { $0.info.id == id } }
    }

    private var openLanes: Int {
        context.desk.widths.all.filter { $0 > context.desk.measure.laneFolded }.count
    }

    var body: some View {
        let reading = reading
        var main: [CommandSlot<SettingsCommand>] = []
        if let reading {
            if !reading.info.listsAccounts {
                main.append(CommandSlot(id: "connect", action: .connect, off: reading.state == .connecting))
            }
            if reading.state.canDisconnect {
                main.append(CommandSlot(id: "disconnect", action: .disconnect, signal: true))
            }
        }
        let fold = openLanes > 1 ? [CommandSlot<SettingsCommand>(id: "fold", action: .fold)] : []
        let plan = CommandBarEngine.plan(main: main, tail: [], fan: [], fold: fold, staticMore: false, width: width - Tokens.Size.edge)
        return CommandHead(plan: plan, moreHelp: appearance.string("settings.action.more"), glyph: glyph, help: help, perform: perform, more: more) {
            EmptyView()
        }
    }

    private func glyph(_ command: SettingsCommand) -> Icon? {
        switch command {
        case .connect: .link
        case .disconnect: .close
        case .fold: .minus
        }
    }

    private func help(_ command: SettingsCommand) -> String {
        switch command {
        case .connect: appearance.string(reading?.asksReconnect == true ? "settings.action.reconnect" : "settings.action.connect")
        case .disconnect: appearance.string("settings.action.disconnect")
        case .fold: appearance.string("settings.action.foldColumn")
        }
    }

    private func perform(_ command: SettingsCommand) {
        switch command {
        case .connect: if let reading { context.flow.perform(reading.step, for: reading.info.id) }
        case .disconnect: disconnecting = reading?.info.id
        case .fold: context.desk.toggleFold(.trailing)
        }
    }

    private func more(_ commands: [SettingsCommand]) -> [MenuEntry] {
        commands.enumerated().map { index, command in
            .row(MenuItem(id: String(index), label: Text(verbatim: help(command))) { perform(command) })
        }
    }
}

enum SettingsCommand: Equatable, Sendable {
    case connect
    case disconnect
    case fold
}
