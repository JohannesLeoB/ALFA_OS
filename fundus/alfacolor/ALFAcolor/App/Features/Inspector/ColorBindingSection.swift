import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel
import Tokens

/// The colour rows of the selection, each with a chain symbol. The chain lists the colour fields: a click binds
/// the colour to one, "release" frees it. A bound row shows the name of its field instead of the hex.
struct ColorBindingSection: View {
    var store: BoardStore
    var items: [Item]
    var slots: [(slot: ColorBinding.Slot, titleKey: String)]

    var body: some View {
        Section("binding.section") {
            ForEach(slots, id: \.titleKey) { row in
                ColorBindingRow(store: store, items: items, slot: row.slot, titleKey: row.titleKey)
            }
        }
    }
}

/// One colour of the selection: its value, its chain and the warning when the bound field is gone.
struct ColorBindingRow: View {
    var store: BoardStore
    var items: [Item]
    var slot: ColorBinding.Slot
    var titleKey: String

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let slotted = items.filter { ColorBinding.hasSlot($0, slot: slot) }
        let ids = Set(slotted.map(\.id))
        let tokens = SharedValue(slotted.map { ColorBinding.token(of: $0, slot: slot) })
        let stored = SharedValue(slotted.map { ColorBinding.stored(of: $0, slot: slot) })
        let missing = slotted.contains { ColorBinding.isMissing($0, slot: slot, in: store.document.tokenSets) }
        let fields = ColorFields.fields(in: store.document.tokenSets)
        let bound = tokens.value.flatMap { $0 } != nil
        Group {
            LabeledContent(LocalizedStringKey(titleKey)) {
                HStack(spacing: theme.space(.s2)) {
                    value(tokens: tokens, stored: stored)
                    Menu {
                        if fields.isEmpty {
                            Text("sidebar.noTokenSet")
                        }
                        ForEach(fields) { field in
                            Button {
                                _ = try? store.bindColor(ids, slot: slot, to: field.name)
                            } label: {
                                HStack {
                                    Rectangle()
                                        .fill(Color(field.color))
                                        .frame(width: theme.space(.s3), height: theme.space(.s3))
                                    Text(verbatim: field.name)
                                }
                            }
                        }
                        Divider()
                        Button("binding.release") {
                            _ = try? store.releaseColor(ids, slot: slot)
                        }
                        .disabled(!bound)
                    } label: {
                        Image(systemName: "link")
                            .foregroundStyle(bound ? theme.color(.accent, scheme) : theme.color(.textMuted, scheme))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel(Text("binding.chain"))
                }
            }
            if missing {
                Text("binding.missing")
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .disabled(ids.isEmpty)
    }

    /// The name of the field when all items follow one, else the hex; "mixed" when they differ.
    @ViewBuilder
    private func value(tokens: SharedValue<String?>, stored: SharedValue<String?>) -> some View {
        if case .value(let name?) = tokens {
            Text(verbatim: name)
        } else if case .value(let hex?) = stored {
            Text(verbatim: hex)
        } else {
            Text("inspector.mixed")
        }
    }
}
