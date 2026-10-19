import Mail
import ShellCore
import SwiftUI

struct OverviewTile: Identifiable {
    let id: String
    let ref: CardRef?
    let message: String?
    let initials: String
    let title: Text
    let date: Text
    let unread: Bool
    let subject: String
    let preview: String
    let current: Bool
    let closable: Bool
    let actions: Bool
}

struct OverviewView: View {
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline
    @Environment(\.mailLaneLink) private var link
    let model: MailModel

    private var title: String { folderTitle(model.currentFolderName) }

    private var modes: [SegmentOption<MailOverviewMode>] {
        [SegmentOption(id: .stack, label: line("mail.overview.stack", model.stackCount)),
         SegmentOption(id: .folder, label: line("mail.overview.folder", title, model.rows.count))]
    }

    private var sizes: [SegmentOption<MailOverviewSize>] {
        [SegmentOption(id: .small, label: word("mail.overview.small")),
         SegmentOption(id: .medium, label: word("mail.overview.medium")),
         SegmentOption(id: .large, label: word("mail.overview.large"))]
    }

    private var tiles: [OverviewTile] {
        if model.overview.mode == .folder {
            return model.rowPresentations.map { row in
                OverviewTile(id: row.id, ref: nil, message: row.draft ? nil : row.id, initials: row.initials,
                             title: row.outgoing ? line("mail.row.to", row.sender) : Text(verbatim: row.sender),
                             date: dateText(row.date), unread: row.unread, subject: row.subject ?? "", preview: row.preview ?? "",
                             current: model.frontRef == .message(row.id), closable: false, actions: !row.draft)
            }
        }
        return model.stackOrder.compactMap { ref in
            switch ref {
            case .message(let id):
                guard let card = model.card(id) else { return nil }
                let party = model.party(card.summary)
                let name = party.name.isEmpty ? MailNames.middle(party.address, limit: MailSheet.cardTitleLimit) : party.name
                return OverviewTile(id: ref.id, ref: ref, message: id, initials: MailNames.initials(party.name), title: Text(verbatim: name),
                                    date: dateText(MailDateLabel.of(card.summary.receivedAt, now: model.now)),
                                    unread: !card.summary.flags.contains(.seen), subject: card.summary.subject,
                                    preview: card.summary.snippet, current: model.frontRef == ref, closable: true, actions: true)
            case .draft(let id):
                guard let card = model.draft(id) else { return nil }
                let first = card.people(.to).first
                return OverviewTile(id: ref.id, ref: ref, message: nil, initials: "",
                                    title: first.map { line("mail.row.to", $0.label) } ?? word("mail.row.newMessage"),
                                    date: word("mail.date.draft"), unread: false,
                                    subject: card.draft.subject.isEmpty ? words("mail.row.newMessage") : card.draft.subject,
                                    preview: card.draft.body, current: model.frontRef == ref, closable: true, actions: false)
            }
        }
    }

    private func dateText(_ label: MailDateLabel) -> Text {
        switch label {
        case .time(let date): Text(date, format: .dateTime.hour().minute())
        case .yesterday: word("mail.date.yesterday")
        case .weekday(let date): Text(date, format: .dateTime.weekday(.wide))
        case .day(let date): Text(date, format: .dateTime.day().month(.abbreviated))
        case .draft: word("mail.date.draft")
        case .none: Text(verbatim: "")
        }
    }

    var body: some View {
        let size = model.overview.size
        let items = tiles
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                SegmentedControl(options: modes, selection: Binding(get: { model.overview.mode }, set: { model.setOverviewMode($0) }))
                Spacer(minLength: 0)
                SegmentedControl(options: sizes, selection: Binding(get: { model.overview.size }, set: { model.setOverviewSize($0) }))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.headerHeight))
            .overlay(alignment: .bottom) { Rectangle().fill(design.color(\.line)).frame(height: hairline) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: CGFloat(size.tileMinWidth)), spacing: CGFloat(Design.Spacing.step8), alignment: .top)],
                          spacing: CGFloat(Design.Spacing.step8)) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, tile in
                        OverviewTileView(model: model, tile: tile, index: index, size: size, dimmed: dimmed(tile))
                    }
                }
                .padding(CGFloat(Design.Spacing.step8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(laneFill)
        .onAppear { grow(true) }
        .onDisappear { grow(false) }
    }

    private func dimmed(_ tile: OverviewTile) -> Bool {
        guard let hot = model.overview.hot else { return false }
        return hot.id != tile.id
    }

    private func grow(_ on: Bool) {
        guard let link else { return }
        if on, link.maximized != .trailing { link.toggleMaximize(.trailing) }
        if !on, link.maximized == .trailing { link.toggleMaximize(.trailing) }
    }
}

struct OverviewTileView: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    let model: MailModel
    let tile: OverviewTile
    let index: Int
    let size: MailOverviewSize
    let dimmed: Bool
    @State private var hovering = false
    @State private var entered = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)) }
    private var hot: Bool { model.overview.hot?.id == tile.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
                Text(verbatim: tile.subject)
                    .designText(\.ink, size: Design.TextSize.body, weight: .medium)
                    .lineLimit(MailSheet.overviewTitleLines)
                    .lineHeight(MailSheet.overviewTileTitleLine * Design.TextSize.body, size: Design.TextSize.body)
                Text(verbatim: tile.preview)
                    .designText(\.inkSecondary, size: Design.TextSize.body)
                    .lineLimit(size.lines)
                    .lineHeight(MailSheet.overviewTileTextLine * Design.TextSize.body, size: Design.TextSize.body)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, CGFloat(Design.Size.edge))
            .padding(.top, CGFloat(Design.Spacing.step4))
            .padding(.bottom, CGFloat(MailSheet.overviewTilePadBottom))
            Spacer(minLength: 0)
        }
        .frame(height: CGFloat(size.tileHeight))
        .background(shape.fill(design.color(\.well)))
        .ring(shape, tile.current ? design.color(\.inkTertiary) : design.color(\.line))
        .overlay(alignment: .bottomTrailing) { actions }
        .clipShape(shape)
        .contentShape(shape)
        .background {
            if hot, let layer = DesignShadows.overviewHoverLight.first {
                shape.inset(by: CGFloat(-layer.spread))
                    .fill(Color(.sRGB, red: layer.color.red, green: layer.color.green, blue: layer.color.blue, opacity: layer.color.alpha))
                    .blur(radius: CGFloat(layer.blur / 2))
                    .offset(x: CGFloat(layer.x), y: CGFloat(layer.y))
            }
        }
        .opacity(entered ? (dimmed ? MailSheet.overviewOtherOpacity : 1) : 0)
        .scaleEffect(entered ? (hot ? MailSheet.overviewHoverScale : dimmed ? MailSheet.overviewOtherScale : 1) : MailSheet.overviewEnterScale)
        .offset(y: entered ? (hot ? -Design.Size.overviewHoverLift : 0) : MailSheet.overviewEnterLift)
        .onAppear {
            guard !reduced else { entered = true; return }
            let curve = Design.Easing.standard
            withAnimation(.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: Design.Duration.overviewEnter)
                .delay(Design.Duration.overviewDelay + Double(index) * Design.Duration.overviewStagger)) { entered = true }
        }
        .onHover { inside in
            hovering = inside
            if inside { model.aimOverview(tile.ref ?? .message(tile.id)) } else if hot { model.aimOverview(nil) }
        }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.tileHover), value: hot)
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.tileHover), value: dimmed)
        .onTapGesture { choose() }
    }

    private var head: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            Group {
                if tile.initials.isEmpty { Glyph(tile.message == nil ? .compose : .person) } else { Text(verbatim: tile.initials) }
            }
            .designText(size: Design.TextSize.small, weight: .medium)
            .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
            .overlay(Circle().strokeBorder(design.color(\.ink).opacity(Design.Opacity.ringOnMark), lineWidth: hairline))
            .overlay(alignment: .topTrailing) {
                if tile.unread {
                    Circle().fill(design.color(\.ink))
                        .frame(width: CGFloat(Design.Spacing.statusDot), height: CGFloat(Design.Spacing.statusDot))
                        .overlay(Circle().strokeBorder(design.color(\.well), lineWidth: CGFloat(Design.Size.markSeparatorRing)))
                        .offset(x: CGFloat(Design.Radius.stroke), y: -CGFloat(Design.Radius.stroke))
                }
            }
            .padding(.trailing, CGFloat(Design.Spacing.step4))
            tile.title.designText(size: Design.TextSize.body, weight: .medium).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            tile.date.designText(\.inkTertiary, size: Design.TextSize.small).monospacedDigit().lineLimit(1).fixedSize()
            if tile.closable {
                CardHeadButton(help: words("mail.card.close"), glyph: .close, ink: design.color(\.ink)) { close() }
            }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.headerHeight))
    }

    @ViewBuilder
    private var actions: some View {
        if tile.actions, let id = tile.message {
            let run = MailDo(model: model)
            HStack(spacing: CGFloat(Design.Spacing.step4)) {
                OverviewAction(help: words("mail.action.reply"), glyph: .reply, tone: \.inkSecondary) { run.message(.reply, id) }
                OverviewAction(help: words("mail.action.archive"), glyph: .archive, tone: \.inkSecondary) { run.message(.archive, id) }
                OverviewAction(help: words("mail.action.trash"), glyph: .trash, tone: \.signal) { run.message(.trash, id) }
            }
            .padding(CGFloat(Design.Spacing.step8))
            .opacity(hot ? 1 : 0)
            .offset(y: hot ? 0 : Design.Size.overviewActionsOffset)
            .allowsHitTesting(hot)
            .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.tileActions), value: hot)
        }
    }

    private func close() {
        switch tile.ref {
        case .message(let id): model.close(id)
        case .draft(let id): Task { await model.closeDraft(id) }
        case nil: break
        }
    }

    private func choose() {
        if let ref = tile.ref {
            model.bring(ref)
            model.openOverview(false)
        } else if let id = tile.message {
            model.openOverview(false)
            Task { await model.open(id) }
        }
    }
}

struct OverviewAction: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let help: String
    let glyph: MailGlyph
    let tone: KeyPath<DesignColors, RGB>
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Design.Size.symbolSize)
        Button(action: action) {
            Glyph(glyph)
                .frame(width: side, height: side)
                .foregroundStyle(design.color(tone))
                .background(Circle().fill(hovering ? design.color(\.hover) : design.color(\.lane)))
                .overlay(Circle().strokeBorder(design.color(\.lineStrong), lineWidth: hairline))
                .contentShape(Circle())
        }
        .buttonStyle(PressScale(scale: SheetValues.pressScale))
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .onHover { hovering = $0 }
    }
}
