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
        let front = state.fanned ? nil : (state.front ?? state.cards.last)
        return front.flatMap { id in readings.first { $0.info.id == id } }
    }

    private var openLanes: Int {
        context.desk.widths.all.filter { $0 > context.desk.measure.laneFolded }.count
    }

    var body: some View {
        let reading = reading
        let asking = reading.map { $0.info.id == disconnecting } ?? false
        var main: [CommandSlot<SettingsCommand>] = []
        if let reading, !asking {
            if !reading.info.listsAccounts {
                main.append(CommandSlot(id: "connect", action: .connect, off: reading.state == .connecting))
            }
            if reading.state.canDisconnect {
                main.append(CommandSlot(id: "disconnect", action: .disconnect, signal: true))
            }
        }
        let tail = reading != nil && asking
            ? [CommandSlot<SettingsCommand>(id: "disconnectPill", action: .disconnect, kind: .pill, cost: ShellValues.commandConfirmCost)] : []
        let fan = !state.cards.isEmpty || state.fanned
            ? [CommandSlot<SettingsCommand>(id: "overview", action: state.fanned ? .back : .overview, accent: state.fanned)] : []
        let fold = openLanes > 1 ? [CommandSlot<SettingsCommand>(id: "fold", action: .fold)] : []
        let plan = CommandBarEngine.plan(main: main, tail: tail, fan: fan, fold: fold, staticMore: false, width: width - Tokens.Size.edge)
        return CommandHead(plan: plan, moreHelp: appearance.string("settings.action.more"), glyph: glyph, help: help, perform: perform, more: more) {
            if let reading { pill(reading) }
        }
    }

    private func glyph(_ command: SettingsCommand) -> Icon? {
        switch command {
        case .connect: .link
        case .disconnect: .close
        case .overview: .grid
        case .back: .fan
        case .fold: .minus
        }
    }

    private func help(_ command: SettingsCommand) -> String {
        switch command {
        case .connect: appearance.string(reading?.asksReconnect == true ? "settings.action.reconnect" : "settings.action.connect")
        case .disconnect: appearance.string("settings.action.disconnect")
        case .overview: appearance.format("settings.overview.tip", String(state.cards.count))
        case .back: appearance.string("settings.action.backToStack")
        case .fold: appearance.string("settings.action.foldColumn")
        }
    }

    private func perform(_ command: SettingsCommand) {
        switch command {
        case .connect: if let reading { context.flow.perform(reading.step, for: reading.info.id) }
        case .disconnect: disconnecting = reading?.info.id
        case .overview, .back: state.toggleFan()
        case .fold: context.desk.toggleFold(.trailing)
        }
    }

    private func more(_ commands: [SettingsCommand]) -> [MenuEntry] {
        commands.enumerated().map { index, command in
            .row(MenuItem(id: String(index), label: Text(verbatim: help(command))) { perform(command) })
        }
    }

    private func pill(_ reading: IntegrationReading) -> some View {
        let name = appearance.string(reading.info.nameKey)
        return ConfirmPill(label: nil, question: Text(verbatim: appearance.format("settings.disconnect.ask", name)),
                           yes: appearance.text("settings.action.disconnect"), no: appearance.text("confirm.no"),
                           holdHint: appearance.text("settings.hold.disconnect"), startsAsking: true, showsProgress: false, onYes: {
                               disconnecting = nil
                               Task { await context.flow.remove(reading.inlets.map(\.id)) }
                           }, onNo: { disconnecting = nil }) {
            Glyph(.close)
        }
    }
}

enum SettingsCommand: Equatable, Sendable {
    case connect
    case disconnect
    case overview
    case back
    case fold
}
