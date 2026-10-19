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
    @State private var tile = SettingsTileSize.medium
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced

    var body: some View {
        GeometryReader { proxy in
            let front = board.front ?? board.cards.last
            let order = board.cards.filter { $0 != front } + board.cards.filter { $0 == front }
            let tops = CardStack.tops(count: order.count)
            ZStack(alignment: .top) {
                if order.isEmpty {
                    RoundedRectangle(cornerRadius: CGFloat(Design.Radius.card))
                        .fill(laneFill)
                        .overlay(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.card)).strokeBorder(design.color(\.line), lineWidth: hairline))
                        .accessibilityLabel(word("settings.stack.empty"))
                }
                ForEach(Array(order.enumerated()), id: \.element) { index, id in
                    SettingsStackCard(
                        host: host, board: board, hub: hub, readings: readings,
                        face: SettingsFace(id: id, readings: readings), depth: order.count - 1 - index, first: index == 0)
                        .frame(height: max(0, proxy.size.height - tops[index]))
                        .offset(y: tops[index])
                        .zIndex(Double(index))
                }
                if board.fanned {
                    SettingsOverview(board: board, faces: order.map { SettingsFace(id: $0, readings: readings) }, front: front, tile: $tile)
                        .transition(.opacity)
                        .zIndex(Double(order.count))
                }
                menuLayer
                toastLayer
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .coordinateSpace(name: SettingsSpace.stack)
            .environment(\.menuState, menus)
            .animation(stackMotion, value: order)
            .animation(.easeOut(duration: Design.Duration.toggle), value: board.fanned)
        }
    }

    private var stackMotion: Animation? {
        ComponentMotion(reduced: reduced).curve(Design.Duration.stack, Design.Easing.stack)
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
            .zIndex(Double(Design.Count.stackMaxCards + 2))
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

    @ViewBuilder
    private var toastLayer: some View {
        if let key = board.toast {
            VStack {
                Spacer(minLength: 0)
                Toast(message: word(key), onDismiss: { board.dismissToast() })
                    .padding(.bottom, CGFloat(Design.Spacing.step44))
            }
            .zIndex(Double(Design.Count.stackMaxCards + 3))
        }
    }
}

private struct SettingsStackCard: View {
    @Bindable var host: AppHost
    let board: SettingsBoard
    let hub: Hub
    let readings: [ServiceReading]
    let face: SettingsFace
    let depth: Int
    let first: Bool
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline

    private var front: Bool { depth == 0 }

    private var step: DesignStackStep? {
        guard depth > 0 else { return nil }
        let steps = design.dark ? Design.stackDark : Design.stackLight
        return steps[min(CardStack.levelIndex(depth: depth), steps.count - 1)]
    }

    private func paint(_ value: RGB) -> Color {
        Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.alpha)
    }

    private var fill: Color { step.map { paint($0.surface) } ?? laneFill }
    private var ink: Color { step.map { paint($0.ink) } ?? design.color(\.ink) }

    private var shape: UnevenRoundedRectangle {
        let top = CGFloat(Design.Radius.card)
        let bottom = CGFloat(Design.Radius.cardBottom)
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if front {
                ScrollView {
                    SettingsCardBody(host: host, board: board, hub: hub, id: face.id)
                        .padding(.top, CGFloat(Design.Spacing.step4))
                        .padding(.bottom, CGFloat(Design.Spacing.step8))
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(ink)
        .background(fill)
        .clipShape(shape)
        .overlay { shape.strokeBorder(design.color(\.line), lineWidth: hairline) }
        .contentShape(shape)
        .onTapGesture { if !front { board.bring(face.id) } }
    }

    private var header: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            Text(verbatim: face.mark)
                .font(.system(size: CGFloat(Design.TextSize.small), weight: .design(Design.Weight.medium)))
                .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                .overlay(Circle().strokeBorder(ink.opacity(Design.Opacity.ringOnMark), lineWidth: hairline))
                .padding(.trailing, CGFloat(Design.Spacing.step12))
            Text(verbatim: face.title)
                .font(.system(size: CGFloat(Design.TextSize.body), weight: .design(Design.Weight.medium)))
                .lineLimit(1)
            Text(verbatim: face.meta)
                .font(.system(size: CGFloat(Design.TextSize.small)))
                .monospacedDigit()
                .lineLimit(1)
                .opacity(SheetValues.cardMetaOpacity)
                .frame(maxWidth: .infinity, alignment: .leading)
            if front {
                SettingsHeaderButton(titleKey: "settings.stack.overview", symbol: .grid, ink: ink) { board.toggleFan() }
            }
            SettingsHeaderButton(titleKey: "settings.card.close", symbol: .close, ink: ink, dim: true) { board.close(face.id) }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .overlay(alignment: .bottom) {
            if front { Rectangle().fill(design.color(\.line)).frame(height: hairline) }
        }
    }
}

private struct SettingsHeaderButton: View {
    @Environment(\.design) private var design
    let titleKey: String
    let symbol: SymbolName
    let ink: Color
    var dim = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            SettingsSymbol(name: symbol)
                .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                .foregroundStyle(ink)
                .opacity(dim && !hovering ? SheetValues.cardCloseOpacity : 1)
                .background(Circle().fill(hovering && !dim ? design.color(\.hover) : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(word(titleKey))
        .accessibilityLabel(word(titleKey))
        .onHover { hovering = $0 }
    }
}

enum SettingsTileSize: CaseIterable {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: CGFloat(Design.Size.overviewTileHeightSmall)
        case .medium: CGFloat(Design.Size.overviewTileHeightMedium)
        case .large: CGFloat(Design.Size.overviewTileHeightLarge)
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .small: CGFloat(Design.Size.overviewTileMinWidthSmall)
        case .medium: CGFloat(Design.Size.overviewTileMinWidthMedium)
        case .large: CGFloat(Design.Size.overviewTileMinWidthLarge)
        }
    }

    var lines: Int {
        switch self {
        case .small: Design.Count.overviewLinesSmall
        case .medium: Design.Count.overviewLinesMedium
        case .large: Design.Count.overviewLinesLarge
        }
    }

    var key: String {
        switch self {
        case .small: "settings.overview.small"
        case .medium: "settings.overview.medium"
        case .large: "settings.overview.large"
        }
    }
}

private struct SettingsOverview: View {
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline
    let board: SettingsBoard
    let faces: [SettingsFace]
    let front: String?
    @Binding var tile: SettingsTileSize

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                SettingsHeaderButton(titleKey: "settings.stack.back", symbol: .fan, ink: design.color(\.ink)) { board.toggleFan() }
                Spacer(minLength: 0)
                SegmentedControl(options: SettingsTileSize.allCases.map { SegmentOption(id: $0, label: word($0.key)) }, selection: $tile)
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.headerHeight))
            Rectangle().fill(design.color(\.line)).frame(height: hairline)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: tile.minWidth), spacing: CGFloat(Design.Spacing.step8))],
                          spacing: CGFloat(Design.Spacing.step8)) {
                    ForEach(faces) { face in
                        OverviewCard(board: board, face: face, current: face.id == front, tile: tile)
                    }
                }
                .padding(CGFloat(Design.Spacing.step8))
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(laneFill)
    }
}

private struct OverviewCard: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let board: SettingsBoard
    let face: SettingsFace
    let current: Bool
    let tile: SettingsTileSize
    @State private var hovering = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Mark { Text(verbatim: face.mark) }
                Text(verbatim: face.title).designText(weight: .medium).lineLimit(1)
                Spacer(minLength: 0)
                SettingsHeaderButton(titleKey: "settings.card.close", symbol: .close, ink: design.color(\.ink), dim: true) { board.close(face.id) }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.headerHeight))
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
                Text(verbatim: face.detail).designText(weight: .medium).lineLimit(2)
                Text(verbatim: face.preview).designText(\.inkSecondary).lineLimit(tile.lines)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CGFloat(Design.Size.edge))
            .padding(.top, CGFloat(Design.Spacing.step4))
            Spacer(minLength: 0)
        }
        .frame(height: tile.height)
        .background(shape.fill(design.color(\.well)))
        .overlay(shape.strokeBorder(current ? design.color(\.inkTertiary) : design.color(\.line), lineWidth: hairline))
        .clipShape(shape)
        .contentShape(shape)
        .offset(y: hovering ? -CGFloat(Design.Size.overviewHoverLift) : 0)
        .animation(.easeOut(duration: Design.Duration.tileHover), value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture { board.bring(face.id) }
    }
}
