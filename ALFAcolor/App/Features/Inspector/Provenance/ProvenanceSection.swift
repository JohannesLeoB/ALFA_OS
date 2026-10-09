import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The origin of the selection: address, file, way in and licence. The import date only reads.
/// Text fields apply on return; a licence applies when it is picked. Each change is one undo step.
struct ProvenanceSection: View {
    var store: BoardStore
    var items: [Item]

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var draft = ProvenanceDraft()
    @State private var invalid = false

    var body: some View {
        let sources = SharedValue(items.map(\.source))
        let hasOrigin = items.contains { $0.source != nil }
        let foreign = items.contains { $0.source != nil && !License.isOwn($0.source) }
        Section("inspector.provenance") {
            TextField("provenance.url", text: $draft.url)
                .onSubmit(apply)
            TextField("provenance.file", text: $draft.file)
                .onSubmit(apply)
            TextField("provenance.via", text: $draft.via)
                .onSubmit(apply)
            Picker("provenance.license", selection: Binding<String>(
                get: { draft.license },
                set: { value in
                    draft.license = value
                    apply()
                })) {
                ForEach(License.presets, id: \.self) { preset in
                    Text(verbatim: Self.name(of: preset)).tag(preset)
                }
            }
            TextField("provenance.license.other", text: $draft.license)
                .onSubmit(apply)
            if invalid {
                Text("provenance.url.invalid")
                    .foregroundStyle(theme.color(.text, scheme))
                    .signalRule(true)
            }
            if let source = sources.value, let date = source?.importedAt {
                LabeledContent("provenance.date") {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                }
            }
            if foreign && draft.license.isEmpty {
                Text("provenance.nolicense")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            if hasOrigin {
                Button("provenance.remove", role: .destructive) {
                    _ = try? store.removeProvenance()
                }
            }
        }
        .onChange(of: store.revision, initial: true) {
            // The fields follow the selection and the board: after an undo they show what is there.
            draft = ProvenanceDraft(source: sources.value.flatMap { $0 })
            invalid = false
        }
    }

    /// Applies the fields to the selection. An address without a scheme is marked and changes nothing.
    private func apply() {
        do {
            _ = try store.perform(provenance: draft)
            invalid = false
        } catch {
            invalid = true
        }
    }

    /// The label of a licence in the list. Own work and unknown are German words of the app; other names are proper names.
    static func name(of preset: String) -> String {
        switch preset {
        case License.own: String(localized: "provenance.license.own")
        case License.unknown: String(localized: "provenance.license.unknown")
        default: preset
        }
    }
}
