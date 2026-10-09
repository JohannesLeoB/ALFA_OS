import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel
import Tokens

/// The sheet "Textstile": the text styles of the token set, the type ramp, the font family from the fonts of this Mac,
/// the licence text and a probe text in light and dark. Values change through BoardStore commands, one undo step each.
struct TextStylesSheet: View {
    var store: BoardStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    @State private var selected: String?
    @State private var draft = TextStylesSheet.plain
    @State private var license = ""
    @State private var probe = String(localized: "type.probeText")
    @State private var base = 16.0
    @State private var factor = 1.25

    private static let plain = Typography(fontFamily: ["sans-serif"], fontSize: 16, fontWeight: 400, letterSpacing: 0, lineHeight: 1.5)

    private var styles: [TypographyStyles.Style] { TypographyStyles.styles(in: store.document.tokenSets) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s4)) {
            HStack {
                Text("type.title")
                    .themeText(theme.text(.heading))
                Spacer()
                Button("type.close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            HStack(alignment: .top, spacing: theme.space(.s4)) {
                styleList
                    .frame(width: theme.grid(25))
                Divider()
                editor
            }
            rampRow
        }
        .padding(theme.space(.s6))
        .frame(minWidth: theme.grid(85), minHeight: theme.grid(60))
        .onAppear {
            selected = styles.first?.name
            load(selected)
        }
        .onChange(of: selected) { _, new in load(new) }
    }

    // MARK: Styles

    private var styleList: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            List(styles, selection: $selected) { style in
                Text(verbatim: style.name).tag(style.name)
            }
            HStack {
                Button(action: add) {
                    Label("type.add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("type.add")
                Spacer()
                Button(action: remove) {
                    Label("type.remove", systemImage: "minus")
                }
                .buttonStyle(.borderless)
                .help("type.remove")
                .disabled(selected == nil)
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let name = selected, styles.contains(where: { $0.name == name }) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.space(.s3)) {
                    Picker("type.family", selection: familyBinding) {
                        ForEach(FontFamilies.installed, id: \.self) { Text(verbatim: $0).tag($0) }
                    }
                    TextField("type.size", value: $draft.fontSize, format: .number)
                        .onSubmit { commit() }
                    TextField("type.weight", value: $draft.fontWeight, format: .number)
                        .onSubmit { commit() }
                    TextField("type.lineHeight", value: $draft.lineHeight, format: .number)
                        .onSubmit { commit() }
                    TextField("type.letterSpacing", value: $draft.letterSpacing, format: .number)
                        .onSubmit { commit() }
                    TextField("type.license", text: $license)
                        .onSubmit { try? store.setTextStyleLicense(name, to: license) }
                    probeRows
                }
            }
        } else {
            Text("type.empty")
                .foregroundStyle(theme.color(.textMuted, scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The probe text in light and dark, in the font of the draft.
    private var probeRows: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            TextField("type.probe", text: $probe)
            ForEach([ColorScheme.light, ColorScheme.dark], id: \.self) { mode in
                Text(verbatim: probe)
                    .font(probeFont)
                    .foregroundStyle(theme.color(.text, mode))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.space(.s3))
                    .background(theme.color(.background, mode), in: RoundedRectangle(cornerRadius: theme.radius(.s)))
                    .environment(\.colorScheme, mode)
            }
        }
    }

    private var probeFont: Font {
        .custom(draft.fontFamily.first ?? "sans-serif", size: CGFloat(draft.fontSize))
            .weight(Self.weight(draft.fontWeight))
    }

    /// The weight of a CSS-style number (100 to 900), as the nearest SwiftUI weight.
    private static func weight(_ w: Int) -> Font.Weight {
        switch w {
        case ..<150: .ultraLight
        case ..<250: .thin
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        case ..<750: .bold
        case ..<850: .heavy
        default: .black
        }
    }

    // MARK: Ramp

    private var rampRow: some View {
        HStack(spacing: theme.space(.s3)) {
            TextField("type.base", value: $base, format: .number)
                .frame(width: theme.grid(12))
            TextField("type.factor", value: $factor, format: .number)
                .frame(width: theme.grid(12))
            Button("type.makeRamp") { try? store.makeTypeRamp(TypeRampSpec(base: base, factor: factor)) }
            Button("type.recalculate") { try? store.recalculateTypeRamp(base: base, factor: factor) }
            Spacer()
        }
    }

    // MARK: Actions

    private var familyBinding: Binding<String> {
        Binding(
            get: { draft.fontFamily.first ?? "" },
            set: { family in
                draft.fontFamily = [family]
                commit()
            })
    }

    private func load(_ name: String?) {
        guard let name, let style = styles.first(where: { $0.name == name }) else { return }
        draft = style.style
        license = store.document.tokenSets
            .first { $0.name == TypographyStyles.setName }?
            .tokens.first { $0.path == [TypographyStyles.group, name] }?
            .description ?? ""
    }

    private func commit() {
        guard let name = selected else { return }
        try? store.changeTextStyle(name, to: draft)
    }

    private func add() {
        let base = String(localized: "type.newStyle")
        let taken = Set(styles.map(\.name))
        var number = 1
        while taken.contains("\(base) \(number)") { number += 1 }
        let name = "\(base) \(number)"
        if (try? store.addTextStyle(name: name, style: Self.plain)) == true { selected = name }
    }

    private func remove() {
        guard let name = selected else { return }
        try? store.removeTextStyle(name)
        selected = styles.first?.name
    }
}
