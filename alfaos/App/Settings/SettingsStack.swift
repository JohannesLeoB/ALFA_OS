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
    @State private var menus = SettingsMenuState()
    @State private var size = OverviewSize.medium
    @State private var hot: String?
    @State private var disconnecting: String?

    var body: some View {
        let front = board.front ?? board.cards.last
        let order = board.cards.filter { $0 != front } + board.cards.filter { $0 == front }
        VStack(spacing: 0) {
            SettingsCommandHead(host: host, board: board, readings: readings, disconnecting: $disconnecting)
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
            .overlay { menuLayer }
            .coordinateSpace(name: SettingsSpace.stack)
            .environment(\.menuState, menus)
        }
        .onChange(of: board.front) { disconnecting = nil }
    }

    private func entry(_ face: SettingsFace, current: Bool) -> OverviewEntry {
        OverviewEntry(id: face.id, mark: .text(face.mark), title: Text(verbatim: face.title), date: Text(verbatim: ""), unread: false,
                      subject: face.detail, preview: face.preview, current: current, close: { board.close(face.id) },
                      choose: { board.bring(face.id) })
    }

    @ViewBuilder
    private var menuLayer: some View {
        if let menu = menus.request {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { menus.request = nil }
                AnchoredMenu(width: menu.width, entries: closing(menu.entries))
                    .offset(x: max(0, menu.anchor.maxX - CGFloat(menu.width)), y: menu.anchor.maxY + CGFloat(Design.Spacing.step4))
            }
        }
    }

    private func closing(_ entries: [MenuEntry]) -> [MenuEntry] {
        entries.map { entry in
            guard case .row(let row) = entry else { return entry }
            return .row(MenuItem(id: row.id, label: row.label, meta: row.meta, check: row.check, danger: row.danger) {
                row.action()
                menus.request = nil
            })
        }
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
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline

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
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            Text(verbatim: face.mark)
                .font(.face(Design.TextSize.small, weight: Design.Weight.medium))
                .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                .overlay(Circle().strokeBorder(ink.opacity(Design.Opacity.ringOnMark), lineWidth: hairline))
                .padding(.trailing, CGFloat(Design.Spacing.step12))
            Text(verbatim: face.title)
                .font(.face(Design.TextSize.body, weight: Design.Weight.medium))
                .lineLimit(1)
            Text(verbatim: face.meta)
                .font(.face(Design.TextSize.small))
                .monospacedDigit()
                .lineLimit(1)
                .opacity(SheetValues.metaOpacity)
                .frame(maxWidth: .infinity, alignment: .leading)
            CardHeadButton(help: words("card.close"), glyph: .close, ink: ink, fills: false) { board.close(face.id) }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .overlay(alignment: .bottom) {
            if front { Rectangle().fill(design.color(\.line)).frame(height: hairline) }
        }
    }
}

struct SettingsCommandHead: View {
    @Environment(\.design) private var design
    @Environment(\.mailLaneLink) private var link
    @Bindable var host: AppHost
    let board: SettingsBoard
    let readings: [ServiceReading]
    @Binding var disconnecting: String?

    var body: some View {
        let front = board.fanned ? nil : (board.front ?? board.cards.last)
        let reading = front.flatMap { id in readings.first { $0.info.id == id } }
        let asking = reading.map { $0.info.id == disconnecting } ?? false
        let fan = (!board.cards.isEmpty || board.fanned) && !asking
        let fold = (link?.openLanes ?? 1) > 1 && !asking
        HStack(spacing: CGFloat(Lane.trailing.headGap)) {
            if let reading, !asking { main(reading) }
            Spacer(minLength: 0)
            if let reading, asking { pill(reading) }
            if fan || fold {
                Rectangle().fill(design.color(\.line)).frame(width: CGFloat(Design.Size.hairline), height: CGFloat(Design.Spacing.step20))
                    .padding(.horizontal, CGFloat(Design.Spacing.step4))
            }
            if fan {
                SymbolButton(help: board.fanned ? words("mail.action.backToStack") : words("mail.overview.tip", MailNames.number(board.cards.count)),
                             glyph: board.fanned ? .fan : .grid, selected: board.fanned, hover: .fill) { board.toggleFan() }
            }
            if fold {
                SymbolButton(help: words("mail.action.foldColumn"), glyph: .minus, hover: .fill) { link?.fold(.trailing) }
            }
        }
        .padding(.leading, CGFloat(Lane.trailing.headLeading))
        .padding(.trailing, CGFloat(Lane.trailing.headTrailing))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .frame(maxWidth: .infinity)
        .background(design.color(\.lane))
    }

    @ViewBuilder
    private func main(_ reading: ServiceReading) -> some View {
        HStack(spacing: CGFloat(Lane.trailing.headGap)) {
            if !reading.info.listsAccounts {
                let off = host.busy || reading.state == .connecting || reading.step == .none
                SymbolButton(help: words(reading.asksReconnect ? "settings.action.reconnect" : "settings.action.connect"), glyph: .link,
                             disabled: off, hover: .fill) {
                    host.perform(reading.step, for: reading.info.id)
                }
            }
            if reading.state.canDisconnect {
                SymbolButton(help: words("settings.action.disconnect"), glyph: .close, tone: \.signal, hoverTone: \.signal, hover: .fill) {
                    disconnecting = reading.info.id
                }
            }
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
