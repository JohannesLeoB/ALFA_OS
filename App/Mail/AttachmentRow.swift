import AppKit
import Design
import Mail
import SwiftUI

struct AttachmentRow: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenMessage
    let row: AttachmentEntry
    @State private var hovering = false
    @State private var anchor = AnchorBox()

    var body: some View {
        HStack(spacing: CGFloat(SheetValues.attachmentGap)) {
            Glyph(.doc)
                .foregroundStyle(appearance.color(\.sheetInkTertiary))
                .frame(width: CGFloat(Tokens.Size.symbolSize), height: CGFloat(Tokens.Size.symbolSize))
                .overlay(RoundedRectangle(cornerRadius: CGFloat(SheetValues.attachmentMarkRadius))
                    .strokeBorder(appearance.color(\.sheetLineStrong), lineWidth: CGFloat(Tokens.Size.hairline)))
            Text(verbatim: row.name)
                .font(Font(Typeface.sheet(size: Tokens.TextSize.body, weight: .medium)))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(verbatim: row.size)
                .font(Font(Typeface.sheet(size: Tokens.TextSize.small)))
                .foregroundStyle(appearance.color(\.sheetInkTertiary))
                .fixedSize()
            Spacer(minLength: 0)
            Glyph.small(.chevron).foregroundStyle(appearance.color(\.sheetInkTertiary))
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step40))
        .background(Capsule().fill(hovering ? appearance.color(\.sheetWell) : Color.clear))
        .contentShape(Capsule())
        .help(Text(verbatim: row.name))
        .background(AnchorMarker(box: anchor))
        .onHover { hovering = $0 }
        .onTapGesture { menu() }
    }

    private func menu() {
        let entries = MenuLine.entries(MenuEngine.attachment(), appearance: appearance) { action in
            if action == .saveAs { save() }
        }
        anchor.showMenu(entries)
    }

    private func save() {
        let inbox = session.inbox
        let id = card.id
        let attachment = row
        Task {
            guard let data = await inbox.attachmentData(id, attachmentID: attachment.id) else { return }
            let panel = NSSavePanel()
            panel.nameFieldStringValue = attachment.name
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }
}
