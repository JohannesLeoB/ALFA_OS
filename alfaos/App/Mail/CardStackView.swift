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
        let seamLayer = seam.first
        let castLayer = cast.first
        VStack(spacing: 0) {
            if front {
                FrontCardContent(model: model, card: card)
            } else {
                head
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(ink)
        .background(fill)
        .overlay(alignment: .top) {
            if let layer = gloss.first { Rectangle().fill(paint(layer.color)).frame(height: 1) }
        }
        .clipShape(shape)
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

    private var head: some View {
        HStack {
            Text(verbatim: card.summary.from).designText(size: Design.TextSize.body, weight: .medium)
            Spacer()
            if let date = card.summary.receivedAt {
                Text(date, format: .dateTime).designText(size: Design.TextSize.small)
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, CGFloat(Design.Size.edge))
        .frame(height: CGFloat(Design.Size.headerHeight))
    }
}

struct FrontCardContent: View {
    let model: MailModel
    let card: ReadingCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step8)) {
                Text(verbatim: card.summary.subject).designText(weight: .medium)
                Text(verbatim: card.summary.from).designText(\.inkSecondary, size: Design.TextSize.small)
                HStack(spacing: CGFloat(Design.Spacing.step12)) {
                    Button { Task { await model.archive(card.id) } } label: { word("mail.action.archive").designText(size: Design.TextSize.small, weight: .medium) }
                    Button { Task { await model.trash(card.id) } } label: { word("mail.action.trash").designText(\.signal, size: Design.TextSize.small, weight: .medium) }
                }
                .buttonStyle(.plain)
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
