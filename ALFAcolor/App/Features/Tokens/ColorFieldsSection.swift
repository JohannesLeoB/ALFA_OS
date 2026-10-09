import SwiftUI
import AppKit
import AppTheme
import ALFAcolorCore
import BoardModel
import Tokens

/// The sidebar section of the token set: the colour fields of the document, with the pipette and the add button.
/// Logic lives in `ColorFields` and `ColorUse`; the section only calls them and keeps the rows' state.
struct ColorFieldsSection: View {
    var store: BoardStore

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    @State private var selected: String?
    @State private var renaming: String?
    @State private var renameText = ""
    @State private var valueEdit: ValueEdit?
    @State private var draft = Color(ColorFields.defaultColor)
    @State private var sampler = NSColorSampler()
    @State private var contrastShown = false

    /// The field whose colour the picker changes. The colour is written when the picker closes, one undo step.
    private struct ValueEdit: Identifiable {
        let name: String
        var id: String { name }
    }

    private var sets: [TokenSet] { store.document.tokenSets }
    private var fields: [ColorFields.Field] { ColorFields.fields(in: sets) }

    var body: some View {
        Section("sidebar.tokenSet") {
            HStack {
                Button(action: pick) {
                    Label("tokens.pipette", systemImage: "eyedropper")
                }
                .buttonStyle(.borderless)
                .help("tokens.pipette")
                Spacer()
                Button { contrastShown = true } label: {
                    Label("contrast.open", systemImage: "square.grid.3x3")
                }
                .buttonStyle(.borderless)
                .help("contrast.open")
                .sheet(isPresented: $contrastShown) {
                    ContrastSheet(store: store)
                }
                TextStylesButton(store: store)
                WorkshopExportButton(store: store)
                Button(action: add) {
                    Label("tokens.add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("tokens.add")
            }
            .popover(item: $valueEdit) { edit in
                ColorPicker("tokens.menu.value", selection: $draft, supportsOpacity: false)
                    .padding()
                    .onDisappear { commitValue(edit.name) }
            }
            if fields.isEmpty {
                Label("sidebar.noTokenSet", systemImage: "swatchpalette")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            ForEach(fields) { field in
                row(field)
            }
            Text("tokens.colorspace.hint")
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
        }
    }

    // MARK: Row

    private func row(_ field: ColorFields.Field) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color(field.color))
                .frame(width: 16, height: 16)
            if renaming == field.name {
                TextField("tokens.menu.rename", text: $renameText)
                    .textFieldStyle(.plain)
                    .onSubmit { commitRename(field.name) }
                    .onExitCommand { renaming = nil }
            } else {
                Text(verbatim: field.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            Text(verbatim: field.color.hex)
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
        }
        .fontWeight(selected == field.name ? .semibold : .regular)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { startRename(field.name) }
        .onTapGesture { selected = field.name }
        .contextMenu { menu(field) }
    }

    @ViewBuilder
    private func menu(_ field: ColorFields.Field) -> some View {
        Button("tokens.menu.value") {
            draft = Color(field.color)
            valueEdit = ValueEdit(name: field.name)
        }
        Button("tokens.menu.rename") { startRename(field.name) }
        Button("tokens.menu.apply") { apply(field) }
            .disabled(store.selection.isEmpty)
        Button("tokens.menu.whereUsed") {
            store.select(ColorUse.items(using: field.color, in: store.activeSpace))
        }
        Divider()
        Button("tokens.menu.delete", role: .destructive) { remove(field.name) }
    }

    // MARK: Actions (each one a change of the document with undo)

    private func add() {
        let name = ColorFields.freeName(base: String(localized: "tokens.newName"), in: sets)
        if (try? store.changeTokenSets(nameKey: "undo.color.add", { try ColorFields.add(name: name, color: ColorFields.defaultColor, to: &$0) })) == true {
            selected = name
        }
    }

    private func startRename(_ name: String) {
        renameText = name
        renaming = name
    }

    private func commitRename(_ old: String) {
        let new = renameText
        renaming = nil
        guard new.trimmingCharacters(in: .whitespacesAndNewlines) != old else { return }
        if (try? store.renameColorField(old, to: new)) == true {
            selected = new.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func commitValue(_ name: String) {
        guard let color = Self.rgb(from: draft) else { return }
        try? store.changeTokenSets(nameKey: "undo.color.value") { try ColorFields.setColor(name, to: color, in: &$0) }
    }

    private func remove(_ name: String) {
        if selected == name { selected = nil }
        try? store.changeTokenSets(nameKey: "undo.color.remove") { try ColorFields.remove(name, from: &$0) }
    }

    private func apply(_ field: ColorFields.Field) {
        try? store.perform(.setFill(store.selection, hex: field.color.hex))
    }

    /// Opens the system pipette. A colour taken from any place on the screen becomes a new field; cancel changes nothing.
    private func pick() {
        sampler.show { picked in
            Task { @MainActor in
                guard let picked, let color = Self.rgb(from: Color(nsColor: picked)) else { return }
                let name = ColorFields.freeName(base: String(localized: "tokens.newName"), in: store.document.tokenSets)
                try? store.changeTokenSets(nameKey: "undo.color.add") { try ColorFields.add(name: name, color: color, to: &$0) }
            }
        }
    }

    /// The colour in sRGB, rounded to 8-bit steps. nil when the colour has no sRGB form.
    static func rgb(from color: Color) -> RGB? {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        return ColorFields.sampled(r: Double(srgb.redComponent), g: Double(srgb.greenComponent), b: Double(srgb.blueComponent))
    }
}
