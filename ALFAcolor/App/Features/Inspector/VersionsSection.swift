import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel
import Document
import Renderers

/// The versions of a code card: its earlier code, newest first. A version can be kept, restored or deleted.
/// Each change is one undo step; a change that is refused shows why, and changes nothing.
struct VersionsSection: View {
    var store: BoardStore
    var items: [Item]

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    /// The notice of the last refused change, as a catalog key. nil after a change that worked.
    @State private var notice: String?

    var body: some View {
        if let card = Self.card(in: items) {
            let versions = store.document.versions.versions(of: card.id)
            Section("inspector.versions") {
                Button("version.keep") { attempt { try store.keepVersion(of: card.id) } }
                if versions.isEmpty {
                    Text("version.empty")
                        .foregroundStyle(theme.color(.textMuted, scheme))
                }
                ForEach(VersionListing(versions).rows, id: \.index) { row in
                    VersionRowView(card: card, row: row, still: still(for: versions[row.index], card: card),
                                   attempt: attempt, restore: { try store.restoreVersion(row.index, of: card.id) },
                                   delete: { try store.deleteVersion(row.index, of: card.id) })
                }
                if let notice {
                    Text(LocalizedStringKey(notice))
                        .foregroundStyle(theme.color(.text, scheme))
                        .signalRule(true)
                }
            }
        }
    }

    /// Runs one change. A refused change shows its notice; a change that worked clears it.
    private func attempt(_ change: () throws -> Bool) {
        do {
            _ = try change()
            notice = nil
        } catch let error as VersionError {
            notice = error.noticeKey
        } catch {
            notice = "version.notice.failed"
        }
    }

    /// The still image of a version, when the cache holds one for its code at the width of the card. It is never taken here.
    private func still(for version: CardVersion, card: CardHead) -> CGImage? {
        CodeStills.shared.cachedStill(for: CodeCard(language: version.language, files: version.files),
                                      width: CodeCardLayout.pageWidth(previewWidth: card.width))
    }

    /// The one selected code card, with the fields the section needs. nil for any other selection.
    static func card(in items: [Item]) -> CardHead? {
        guard items.count == 1, let item = items.first, case .code(_, _, let width) = item.content else { return nil }
        return CardHead(id: item.id, width: width)
    }

    struct CardHead {
        let id: ItemID
        let width: Double?
    }
}

/// One version of the list: its time, its reason, a still image when the cache holds one, and its two actions.
private struct VersionRowView: View {
    var card: VersionsSection.CardHead
    var row: VersionListing.Row
    var still: CGImage?
    var attempt: (() throws -> Bool) -> Void
    var restore: () throws -> Bool
    var delete: () throws -> Bool

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            if let still {
                Image(decorative: still, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: theme.space(.s8))
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius(.s)))
            }
            LabeledContent {
                Text(row.date, format: .dateTime.day().month().year().hour().minute())
            } label: {
                Text(LocalizedStringKey(row.reason.nameKey))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            HStack {
                Button("version.restore") { attempt(restore) }
                Spacer()
                Button("version.delete", role: .destructive) { attempt(delete) }
            }
            .buttonStyle(.borderless)
        }
    }
}
