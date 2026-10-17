import AppKit
import Mail
import ShellCore
import SwiftUI

struct CardStackView: View {
    let model: MailModel

    var body: some View {
        GeometryReader { proxy in
            let cards = model.cards
            let front = model.selectedMessage ?? cards.last?.id
            let order = cards.filter { $0.id != front } + cards.filter { $0.id == front }
            let tops = CardStack.tops(count: order.count)
            ZStack(alignment: .top) {
                ForEach(Array(order.enumerated()), id: \.element.id) { index, card in
                    StackCard(model: model, card: card, depth: order.count - 1 - index, first: index == 0)
                        .frame(height: max(0, proxy.size.height - tops[index]))
                        .offset(y: tops[index])
                        .zIndex(Double(index))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .animation(
                NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .linear(duration: 0.001) : .spring(duration: Design.Duration.stack, bounce: 0.1),
                value: order.map(\.id))
        }
    }
}

private struct StackCard: View {
    let model: MailModel
    let card: ReadingCard
    let depth: Int
    let first: Bool
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
            CardHeader(model: model, card: card, front: front, ink: ink)
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
