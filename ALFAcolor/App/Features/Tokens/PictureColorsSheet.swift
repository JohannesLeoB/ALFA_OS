import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel
import ColorLab
import Document
import Tokens

/// The inspector button of an image: opens the sheet that takes the colours of the picture.
struct PictureColorsButton: View {
    var store: BoardStore
    var items: [Item]

    @State private var showing = false

    var body: some View {
        let assetID = items.lazy.compactMap { item -> String? in
            guard case .image(let id, _, _) = item.content else { return nil }
            return id
        }.first
        if let assetID {
            Button("inspector.picture.colors") { showing = true }
                .sheet(isPresented: $showing) {
                    PictureColorsSheet(store: store, assetID: assetID)
                }
        }
    }
}

/// Shows the colours of a picture with their shares. The threshold merges similar tones; apply adds colour fields.
/// The extraction runs in the background once; the threshold only merges the found colours again.
struct PictureColorsSheet: View {
    var store: BoardStore
    var assetID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    @State private var found: [Swatch]?
    @State private var threshold: Double = 6

    private var swatches: [Swatch] { Palette.unify(found ?? [], threshold: threshold) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s4)) {
            Text("picture.colors.title")
                .font(theme.text(.heading).font)
            if let found {
                if found.isEmpty {
                    Text("picture.colors.none")
                        .foregroundStyle(theme.color(.textMuted, scheme))
                } else {
                    Slider(value: $threshold, in: 0...20, step: 1) {
                        Text("picture.colors.threshold")
                    }
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                        row(swatch)
                    }
                }
            } else {
                ProgressView("picture.colors.loading")
            }
            HStack {
                Spacer()
                Button("picture.colors.cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("picture.colors.apply") { apply() }
                    .disabled(swatches.isEmpty)
            }
        }
        .padding(theme.space(.s6))
        .task { found = await PictureColorsJob.extract(store.document.assets[assetID]) }
    }

    private func row(_ swatch: Swatch) -> some View {
        HStack(spacing: theme.space(.s2)) {
            Rectangle()
                .fill(Color(swatch.color))
                .frame(width: 16, height: 16)
            Text(verbatim: swatch.color.hex)
                .font(theme.text(.caption).font.monospaced())
            Spacer(minLength: 0)
            Text(verbatim: String(format: "%.0f %%", swatch.share * 100))
                .font(theme.text(.caption).font)
                .foregroundStyle(theme.color(.textMuted, scheme))
        }
    }

    /// Adds one colour field per found tone, one undo step, then closes the sheet.
    private func apply() {
        let picked = swatches.map { ColorFields.PictureShare(color: $0.color, share: $0.share) }
        let base = String(localized: "picture.colors.base")
        let done = try? store.changeTokenSets(nameKey: "undo.picture.colors") {
            try ColorFields.addPictureColors(picked, base: base, assetID: assetID, importedAt: .now, to: &$0)
        }
        if done == true { dismiss() }
    }
}

/// The colours of a picture, taken in the background: decoding and extraction run off the main actor.
enum PictureColorsJob {
    static func extract(_ entry: AssetStore.Entry?) async -> [Swatch] {
        await Task.detached(priority: .userInitiated) {
            guard let entry, let data = try? entry.data(), let image = PictureDecode.image(data) else { return [] }
            return Palette.extract(from: image)
        }.value
    }
}
