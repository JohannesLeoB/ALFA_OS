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
        HStack(spacing: CGFloat(Tokens.Spacing.step12)) {
            Glyph(.doc)
                .foregroundStyle(appearance.color(\.sheetInkTertiary))
                .frame(width: CGFloat(Tokens.Size.symbolSize), height: CGFloat(Tokens.Size.symbolSize))
                .overlay(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.notice))
                    .strokeBorder(appearance.color(\.sheetLineStrong), lineWidth: CGFloat(Tokens.Size.hairline)))
            Text(verbatim: PersonName.middle(row.name, limit: SheetValues.attachmentNameLimit))
                .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                .lineLimit(1)
            Text(verbatim: row.size)
                .font(.face(Tokens.TextSize.small))
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
        let entries = MenuLine.entries(MenuEngine.attachment(name: row.name), appearance: appearance) { action in
            switch action {
            case .preview: run { AttachmentPreview.show($0, name: row.name) }
            case .print: run { AttachmentExport.printAttachment($0, name: row.name) }
            case .pdf: run { AttachmentExport.savePDF($0, name: row.name) }
            case .saveAs: run { AttachmentExport.save($0, name: row.name) }
            case .otherProject:
                ProjectFolderList.save(session.inbox, appearance: appearance, message: card.id, attachment: row, anchor: anchor)
            default: break
            }
        }
        anchor.showMenu(entries)
    }

    private func run(_ work: @escaping @MainActor (Data) -> Bool) {
        let inbox = session.inbox
        let id = card.id
        let attachment = row.id
        Task {
            guard let data = await inbox.attachmentData(id, attachmentID: attachment) else { return }
            if !work(data) { inbox.announce(.attachmentFailed) }
        }
    }
}
