import Hub
import Mail
import ShellCore
import SwiftUI

struct SettingsFace: Identifiable {
    let id: String
    let title: String
    let meta: String
    let mark: String
    let detail: String
    let preview: String

    init(id: String, readings: [ServiceReading]) {
        self.id = id
        if let reading = readings.first(where: { $0.info.id == id }) {
            let name = String(localized: String.LocalizationValue(reading.info.nameKey))
            title = name
            meta = String(localized: String.LocalizationValue(reading.state.key))
            mark = SettingsFormat.initial(name)
            detail = String(localized: String.LocalizationValue(reading.info.useKey))
            preview = meta
        } else if let section = SettingsSection(rawValue: id) {
            let name = String(localized: String.LocalizationValue(section.key))
            title = name
            meta = String(localized: String.LocalizationValue(section.detailKey))
            mark = SettingsFormat.initial(name)
            detail = meta
            preview = ""
        } else {
            title = id
            meta = ""
            mark = SettingsFormat.initial(id)
            detail = ""
            preview = ""
        }
    }
}

struct SettingsStackPane: View {
    @Bindable var host: AppHost
    let board: SettingsBoard
    let hub: Hub
    let readings: [ServiceReading]
    @State private var size = OverviewSize.medium
    @State private var hot: String?
    @State private var disconnecting: String?

    var body: some View {
        let front = board.front ?? board.cards.last
        let order = board.cards.filter { $0 != front } + board.cards.filter { $0 == front }
        GeometryReader { proxy in
            VStack(spacing: 0) {
                SettingsCommandHead(host: host, board: board, readings: readings, width: proxy.size.width, disconnecting: $disconnecting)
                CardPile(order: order, fanned: board.fanned) { id, depth, first in
                    SettingsStackCard(host: host, board: board, hub: hub, face: SettingsFace(id: id, readings: readings), depth: depth, first: first,
                                      disconnecting: disconnecting)
                } overview: {
                    CardOverview(entries: order.map { entry(SettingsFace(id: $0, readings: readings), current: $0 == front) },
                                 size: size, resize: { size = $0 }, hot: hot, aim: { hot = $0 }) {
                        EmptyView()
                    }
                } note: {
                    if let key = board.toast {
                        Toast(message: word(key), onDismiss: { board.dismissToast() })
                    }
                }
            }
        }
        .onChange(of: board.front) { disconnecting = nil }
    }

    private func entry(_ face: SettingsFace, current: Bool) -> OverviewEntry {
        OverviewEntry(id: face.id, mark: .text(face.mark), title: Text(verbatim: face.title), date: Text(verbatim: ""), unread: false,
                      subject: face.detail, preview: face.preview, current: current, close: { board.close(face.id) },
                      choose: { board.bring(face.id) })
    }
}

private struct SettingsStackCard: View {
    @Bindable var host: AppHost
    let board: SettingsBoard
    let hub: Hub
    let face: SettingsFace
    let depth: Int
    let first: Bool
    let disconnecting: String?

    private var front: Bool { depth == 0 }

    var body: some View {
        CardFace(depth: depth, first: first, bring: { board.bring(face.id) }) { ink in
            header(ink)
        } content: {
            ScrollView {
                SettingsCardBody(host: host, board: board, hub: hub, id: face.id, disconnecting: disconnecting == face.id)
                    .padding(.top, CGFloat(Design.Spacing.step4))
                    .padding(.bottom, CGFloat(Design.Spacing.step8))
            }
            .scrollIndicators(.never)
        }
    }

    private func header(_ ink: Color) -> some View {
        CardHeader(front: front, ink: ink) {
            Text(verbatim: face.mark)
        } title: {
            Text(verbatim: face.title)
                .font(.face(Design.TextSize.body, weight: Design.Weight.medium))
                .lineLimit(1)
        } meta: {
            Text(verbatim: face.meta)
                .font(.face(Design.TextSize.small))
                .monospacedDigit()
                .lineLimit(1)
                .opacity(SheetValues.metaOpacity)
                .frame(maxWidth: .infinity, alignment: .leading)
        } trailing: {
            CardHeadButton(help: words("card.close"), glyph: .close, ink: ink, fills: false) { board.close(face.id) }
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

struct SettingsCommandHead: View {
    @Environment(\.mailLaneLink) private var link
    @Bindable var host: AppHost
    let board: SettingsBoard
    let readings: [ServiceReading]
    let width: Double
    @Binding var disconnecting: String?

    private var reading: ServiceReading? {
        let front = board.fanned ? nil : (board.front ?? board.cards.last)
        return front.flatMap { id in readings.first { $0.info.id == id } }
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
        let tail = reading != nil && asking ? [CommandSlot<SettingsCommand>(id: "disconnectPill", action: .disconnect, kind: .pill,
                                                                               cost: SheetValues.commandConfirmCost)] : []
        let fan = !board.cards.isEmpty || board.fanned
            ? [CommandSlot<SettingsCommand>(id: "overview", action: board.fanned ? .back : .overview, accent: board.fanned)] : []
        let fold = (link?.openLanes ?? 1) > 1 ? [CommandSlot<SettingsCommand>(id: "fold", action: .fold)] : []
        let plan = CommandBar.plan(main: main, tail: tail, fan: fan, fold: fold, staticMore: false, width: width - Design.Size.edge)
        return CommandHead(plan: plan, glyph: glyph, help: help, perform: perform, more: more) {
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
        case .connect: words(reading?.asksReconnect == true ? "settings.action.reconnect" : "settings.action.connect")
        case .disconnect: words("settings.action.disconnect")
        case .overview: words("mail.overview.tip", String(board.cards.count))
        case .back: words("mail.action.backToStack")
        case .fold: words("mail.action.foldColumn")
        }
    }

    private func perform(_ command: SettingsCommand) {
        switch command {
        case .connect: if let reading { host.perform(reading.step, for: reading.info.id) }
        case .disconnect: disconnecting = reading?.info.id
        case .overview, .back: board.toggleFan()
        case .fold: link?.fold(.trailing)
        }
    }

    private func more(_ commands: [SettingsCommand]) -> [MenuEntry] {
        commands.enumerated().map { index, command in
            .row(MenuItem(id: String(index), label: Text(verbatim: help(command))) { perform(command) })
        }
    }

    private func pill(_ reading: ServiceReading) -> some View {
        let name = String(localized: String.LocalizationValue(reading.info.nameKey))
        return ConfirmPill(label: nil, question: Text(verbatim: SettingsFormat.text("settings.disconnect.ask", name)),
                           yes: word("settings.action.disconnect"), no: word("confirm.no"), holdHint: word("settings.hold.disconnect"),
                           startsAsking: true, showsProgress: false, onYes: {
                               disconnecting = nil
                               Task { for inlet in reading.inlets { await host.remove(inlet.id) } }
                           }, onNo: { disconnecting = nil }) {
            Glyph(.close)
        }
    }
}
