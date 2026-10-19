import Hub
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
    @Environment(\.design) private var design

    var body: some View {
        let front = board.front ?? board.cards.last
        let order = board.cards.filter { $0 != front } + board.cards.filter { $0 == front }
        CardPile(order: order, fanned: board.fanned) { id, depth, first in
            SettingsStackCard(host: host, board: board, hub: hub, face: SettingsFace(id: id, readings: readings), depth: depth, first: first)
        } overview: {
            CardOverview(entries: order.map { entry(SettingsFace(id: $0, readings: readings), current: $0 == front) },
                         size: size, resize: { size = $0 }, hot: hot, aim: { hot = $0 }) {
                CardHeadButton(help: words("settings.stack.back"), glyph: .fan, ink: design.color(\.ink), dim: false) { board.toggleFan() }
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
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline

    private var front: Bool { depth == 0 }

    var body: some View {
        CardFace(depth: depth, first: first, bring: { board.bring(face.id) }) { ink in
            header(ink)
        } content: {
            ScrollView {
                SettingsCardBody(host: host, board: board, hub: hub, id: face.id)
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
            if front {
                CardHeadButton(help: words("settings.stack.overview"), glyph: .grid, ink: ink, dim: false) { board.toggleFan() }
            }
            CardHeadButton(help: words("card.close"), glyph: .close, ink: ink) { board.close(face.id) }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .overlay(alignment: .bottom) {
            if front { Rectangle().fill(design.color(\.line)).frame(height: hairline) }
        }
    }
}
