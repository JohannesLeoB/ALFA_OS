import AppKit
import Mail
import ShellCore
import SwiftUI

struct CardStackView: View {
    let model: MailModel
    @State private var fanned = false
    @State private var tileSize = OverviewSize.medium

    var body: some View {
        GeometryReader { proxy in
            let cards = model.cards
            let front = model.selectedMessage ?? cards.last?.id
            let order = cards.filter { $0.id != front } + cards.filter { $0.id == front }
            let tops = CardStack.tops(count: order.count)
            ZStack(alignment: .top) {
                ForEach(Array(order.enumerated()), id: \.element.id) { index, card in
                    StackCard(model: model, card: card, depth: order.count - 1 - index, first: index == 0, fanned: $fanned)
                        .frame(height: max(0, proxy.size.height - tops[index]))
                        .offset(y: tops[index])
                        .zIndex(Double(index))
                }
                if fanned {
                    CardOverview(model: model, cards: order, front: front, size: $tileSize, fanned: $fanned)
                        .transition(.opacity)
                        .zIndex(Double(order.count))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .animation(
                NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .linear(duration: 0.001) : .spring(duration: Design.Duration.stack, bounce: 0.1),
                value: order.map(\.id))
            .animation(.easeOut(duration: Design.Duration.toggle), value: fanned)
            .onChange(of: model.cards.isEmpty) { _, empty in if empty { fanned = false } }
        }
    }
}

private struct StackCard: View {
    let model: MailModel
    let card: ReadingCard
    let depth: Int
    let first: Bool
    @Binding var fanned: Bool
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.cardSurface) private var surface
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
    private var lacquer: Bool { surface == .lacquer }
    private var light: Bool { step.map { $0.surface.red >= 0.75 } ?? true }

    private var gloss: [ShadowLayer] {
        if front { return design.dark ? DesignSurface.topGlossFrontDark : DesignSurface.topGlossFrontLight }
        return light ? DesignSurface.topGlossBackLightCard : DesignSurface.topGlossBackDarkCard
    }

    private var seam: [ShadowLayer] {
        if design.dark { return DesignSurface.topSeamDark }
        return front ? DesignSurface.topSeamFrontLight : DesignSurface.topSeamBackLight
    }

    private var cast: [ShadowLayer] {
        if first { return [] }
        return design.dark ? DesignSurface.castShadowDark : DesignSurface.castShadowLight
    }

    private var shape: UnevenRoundedRectangle {
        let top = CGFloat(Design.Radius.card)
        let bottom = CGFloat(Design.Radius.cardBottom)
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top)
    }

    var body: some View {
        let seamLayer = lacquer ? seam.first : nil
        let castLayer = lacquer ? cast.first : nil
        VStack(spacing: 0) {
            CardHeader(model: model, card: card, front: front, ink: ink, fanned: $fanned)
            if front {
                divider
                FrontCardContent(model: model, card: card)
                divider
                CardFooter(model: model, card: card)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(ink)
        .background(fill)
        .overlay(alignment: .top) {
            if lacquer, let layer = gloss.first { Rectangle().fill(paint(layer.color)).frame(height: CGFloat(layer.y)) }
        }
        .clipShape(shape)
        .overlay {
            if !lacquer { shape.strokeBorder(design.color(\.line), lineWidth: hairline) }
        }
        .background {
            ZStack {
                if let layer = castLayer {
                    shape.inset(by: CGFloat(-layer.spread))
                        .fill(paint(layer.color))
                        .blur(radius: CGFloat(layer.blur / 2))
                        .offset(x: CGFloat(layer.x), y: CGFloat(layer.y))
                }
                if let layer = seamLayer {
                    shape.fill(paint(layer.color)).offset(y: CGFloat(layer.y))
                }
            }
        }
        .contentShape(shape)
        .onTapGesture { if !front { Task { await model.open(card.id) } } }
    }

    private var divider: some View {
        Rectangle().fill(design.color(\.line)).frame(height: hairline)
    }
}

private struct CardHeader: View {
    let model: MailModel
    let card: ReadingCard
    let front: Bool
    let ink: Color
    @Binding var fanned: Bool
    @Environment(\.design) private var design

    private var initials: String {
        let parts = card.summary.from.split(separator: " ").prefix(2).compactMap(\.first)
        return String(parts).uppercased()
    }

    private var address: String {
        let raw = card.summary.fromRaw
        guard let open = raw.lastIndex(of: "<"), let close = raw.lastIndex(of: ">"), open < close else { return raw }
        return String(raw[raw.index(after: open)..<close])
    }

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            Text(verbatim: initials)
                .designText(size: Design.TextSize.small, weight: .medium)
                .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                .background(Circle().fill(design.color(\.hover)))
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: card.summary.from).designText(size: Design.TextSize.body, weight: .medium).lineLimit(1)
                if front {
                    Text(verbatim: address).designText(\.inkSecondary, size: Design.TextSize.small).lineLimit(1)
                } else if let date = card.summary.receivedAt {
                    Text(date, format: .dateTime).designText(\.inkSecondary, size: Design.TextSize.small).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if front {
                CardButton(symbol: "square.grid.2x2", label: "mail.overview.open") { fanned = true }
                CardButton(symbol: "xmark", label: "mail.card.close") { model.close(card.id) }
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, CGFloat(Design.Size.edge))
        .frame(height: CGFloat(Design.Size.headerHeight))
    }
}

private struct CardFooter: View {
    let model: MailModel
    let card: ReadingCard

    private var starred: Bool { card.summary.flags.contains(.flagged) }

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step4)) {
            CardButton(symbol: "folder.badge.plus", label: "mail.footer.project") { model.mailToProjectFolder(card.id) }
            Spacer(minLength: 0)
            CardButton(symbol: "archivebox", label: "mail.action.archive") { Task { await model.archive(card.id) } }
            CardButton(symbol: "trash", label: "mail.action.trash") { Task { await model.trash(card.id) } }
            Menu {
                Button { Task { await model.setStarred(card.id, !starred) } } label: { word(starred ? "mail.footer.unstar" : "mail.footer.star") }
                Button { Task { await model.setRead(card.id, false) } } label: { word("mail.footer.unread") }
                Button { Task { await model.markSpam(card.id) } } label: { word("mail.footer.spam") }
            } label: {
                CardSymbol(symbol: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(Text(LocalizedStringKey("mail.footer.more")))
        }
        .padding(.horizontal, CGFloat(Design.Size.edge))
        .frame(height: CGFloat(Design.Size.footerHeight))
    }
}

private struct CardButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { CardSymbol(symbol: symbol) }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LocalizedStringKey(label)))
    }
}

private struct CardSymbol: View {
    let symbol: String
    @Environment(\.design) private var design
    @State private var hovering = false

    var body: some View {
        Image(systemName: symbol)
            .designText(\.inkSecondary, size: Design.TextSize.body)
            .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
            .background(Circle().fill(hovering ? design.color(\.hover) : Color.clear))
            .contentShape(Circle())
            .onHover { hovering = $0 }
    }
}

struct FrontCardContent: View {
    let model: MailModel
    let card: ReadingCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step8)) {
                Text(verbatim: card.summary.subject).designText(weight: .medium)
                if let hint = model.actionFailure(for: card.id) { hintWords(hint).designText(\.signal, size: Design.TextSize.small) }
                content(card.content).designText(size: Design.TextSize.body)
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CGFloat(Design.Size.edge))
        }
    }

    @ViewBuilder
    private func content(_ content: MailCardContent) -> some View {
        switch content {
        case .text(let text): Text(verbatim: text)
        case .html(let html, _): Text(verbatim: MailText.plain(html))
        case .bodyLoading, .conversation, .draftNotice: word(content.key ?? "mail.card.bodyLoading")
        }
    }
}

enum OverviewSize: CaseIterable {
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
        case .small: 3
        case .medium: 4
        case .large: 8
        }
    }

    var key: String {
        switch self {
        case .small: "mail.overview.small"
        case .medium: "mail.overview.medium"
        case .large: "mail.overview.large"
        }
    }
}

private struct CardOverview: View {
    let model: MailModel
    let cards: [ReadingCard]
    let front: String?
    @Binding var size: OverviewSize
    @Binding var fanned: Bool
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                CardButton(symbol: "rectangle.stack", label: "mail.overview.back") { fanned = false }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach(OverviewSize.allCases, id: \.self) { option in
                        Button { size = option } label: {
                            word(option.key)
                                .designText(size == option ? \.onInverse : \.inkSecondary, size: Design.TextSize.small, weight: .medium)
                                .padding(.horizontal, CGFloat(Design.Spacing.step8))
                                .frame(height: CGFloat(Design.Size.chipHeight))
                                .background(Capsule().fill(size == option ? design.color(\.inverse) : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CGFloat(Design.Spacing.step4) / 2)
                .overlay(Capsule().strokeBorder(design.color(\.lineStrong), lineWidth: hairline))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.headerHeight))
            Rectangle().fill(design.color(\.line)).frame(height: hairline)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: size.minWidth), spacing: CGFloat(Design.Spacing.step8))],
                          spacing: CGFloat(Design.Spacing.step8)) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        OverviewTile(model: model, card: card, index: index, current: card.id == front, size: size, fanned: $fanned)
                    }
                }
                .padding(CGFloat(Design.Spacing.step8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(laneFill)
    }
}

private struct OverviewTile: View {
    let model: MailModel
    let card: ReadingCard
    let index: Int
    let current: Bool
    let size: OverviewSize
    @Binding var fanned: Bool
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    @State private var hovering = false
    @State private var entered = false

    private var unread: Bool { !card.summary.flags.contains(.seen) }

    private var initials: String {
        String(card.summary.from.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Text(verbatim: initials)
                    .designText(size: Design.TextSize.small, weight: .medium)
                    .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                    .overlay(Circle().strokeBorder(design.color(\.lineStrong), lineWidth: hairline))
                    .overlay(alignment: .topTrailing) {
                        if unread {
                            Circle().fill(design.color(\.ink)).frame(width: CGFloat(Design.Spacing.step8), height: CGFloat(Design.Spacing.step8))
                                .overlay(Circle().strokeBorder(design.color(\.well), lineWidth: CGFloat(Design.Radius.stroke)))
                                .offset(x: CGFloat(Design.Radius.stroke), y: -CGFloat(Design.Radius.stroke))
                        }
                    }
                Text(verbatim: card.summary.from).designText(weight: .medium).lineLimit(1)
                Spacer(minLength: 0)
                if let date = card.summary.receivedAt {
                    Text(date, format: .dateTime.day().month()).designText(\.inkTertiary, size: Design.TextSize.small).lineLimit(1)
                }
                CardButton(symbol: "xmark", label: "mail.card.close") { model.close(card.id) }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.headerHeight))
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
                Text(verbatim: card.summary.subject).designText(weight: .medium).lineLimit(2)
                Text(verbatim: card.summary.snippet).designText(\.inkSecondary).lineLimit(size.lines)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CGFloat(Design.Size.edge))
            .padding(.top, CGFloat(Design.Spacing.step4))
            Spacer(minLength: 0)
        }
        .frame(height: size.height)
        .background(shape.fill(design.color(\.well)))
        .overlay(shape.strokeBorder(current ? design.color(\.inkTertiary) : design.color(\.line), lineWidth: hairline))
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: CGFloat(Design.Spacing.step4)) {
                CardButton(symbol: "archivebox", label: "mail.action.archive") { Task { await model.archive(card.id) } }
                CardButton(symbol: "trash", label: "mail.action.trash") { Task { await model.trash(card.id) } }
            }
            .padding(CGFloat(Design.Spacing.step8))
            .opacity(hovering ? 1 : 0)
            .allowsHitTesting(hovering)
        }
        .clipShape(shape)
        .contentShape(shape)
        .opacity(entered ? 1 : 0)
        .offset(y: entered ? 0 : CGFloat(Design.Spacing.step16))
        .onAppear {
            withAnimation(.easeOut(duration: Design.Duration.overviewEnter).delay(Design.Duration.overviewDelay + Double(index) * Design.Duration.overviewStagger)) { entered = true }
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: Design.Duration.tileActions), value: hovering)
        .onTapGesture {
            fanned = false
            Task { await model.open(card.id) }
        }
    }
}
