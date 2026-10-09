import AppKit
import AppTheme
import Renderers
import SwiftUI

/// The lab over the canvas: the code of a card on the left, its running page on the right, and its controls below.
/// Escape or the close button hides it. The draft stays in the model.
struct LabView: View {
    let model: LabModel
    var onClose: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                editor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle()
                    .fill(theme.color(.border, scheme))
                    .frame(width: 1)
                LabStageView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            LabControlsView(model: model)
            footer
        }
        .background(theme.color(.background, scheme))
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack(spacing: theme.space(.s3)) {
            Text(LocalizedStringKey("lab.title"))
                .themeText(theme.text(.heading))
            artPicker
            widthPicker
            Spacer()
            // Escape closes the lab also while the editor has the focus.
            Button(LocalizedStringKey("lab.close"), action: onClose)
                .keyboardShortcut(.cancelAction)
        }
        .padding(theme.space(.s3))
    }

    private var artPicker: some View {
        Picker(selection: Binding(get: { model.session.draft.art }, set: { model.setArt($0) })) {
            ForEach(LabDraft.Art.allCases, id: \.self) { art in
                Text(LocalizedStringKey(artTitle(art))).tag(art)
            }
        } label: {
            Text(LocalizedStringKey("lab.art"))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var widthPicker: some View {
        Picker(selection: Binding(get: { model.session.draft.width }, set: { model.setWidth($0) })) {
            ForEach(LabStage.widths, id: \.self) { width in
                widthTitle(width).tag(width)
            }
        } label: {
            Text(LocalizedStringKey("lab.width"))
        }
        .fixedSize()
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            tabPicker
            LabTextEditor(text: Binding(
                get: { model.session.draft.text(model.session.tab) },
                set: { model.edit($0, in: model.session.tab) }
            ), font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                colour: NSColor(theme.color(.text, scheme)), onCancel: onClose)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: theme.space(.s2)) {
                PasteButton(payloadType: String.self) { strings in
                    let text = strings.joined(separator: "\n")
                    if !text.isEmpty { model.paste(text) }
                }
                Text(LocalizedStringKey("lab.paste.hint"))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .padding(theme.space(.s3))
    }

    private var tabPicker: some View {
        Picker(selection: Binding(get: { model.session.tab }, set: { model.show($0) })) {
            ForEach(model.session.draft.tabs, id: \.self) { tab in
                Text(LocalizedStringKey(tabTitle(tab))).tag(tab)
            }
        } label: {
            Text(LocalizedStringKey("lab.tabs"))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var footer: some View {
        HStack(spacing: theme.space(.s3)) {
            if let message = model.message {
                Text(LocalizedStringKey(message.key))
                    .foregroundStyle(message.isProblem ? theme.color(.coral, scheme) : theme.color(.textMuted, scheme))
            } else {
                Text(LocalizedStringKey("lab.hint.commit"))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            Spacer()
            Button(LocalizedStringKey("lab.commit")) { model.commit() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.session.draft.files.isEmpty)
        }
        .themeText(theme.text(.caption))
        .padding(theme.space(.s3))
    }

    private func artTitle(_ art: LabDraft.Art) -> String {
        switch art {
        case .html: "lab.art.html"
        case .tailwind: "lab.art.tailwind"
        case .react: "lab.art.react"
        }
    }

    private func tabTitle(_ tab: LabDraft.Tab) -> String {
        switch tab {
        case .html: "lab.tab.html"
        case .css: "lab.tab.css"
        case .script: model.session.draft.art == .react ? "lab.tab.jsx" : "lab.tab.js"
        }
    }

    private func widthTitle(_ width: Double) -> Text {
        width == 0 ? Text(LocalizedStringKey("lab.width.fill")) : Text(verbatim: "\(Int(width))")
    }
}
