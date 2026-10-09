import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel

/// The header of the selection: the symbol and the name of the kind, or the count of several items.
struct HeaderSection: View {
    var items: [Item]

    var body: some View {
        let kind = Inspection(items: items).kind.value
        Section {
            if items.count == 1, let kind {
                Label(LocalizedStringKey(kind.nameKey), systemImage: kind.symbolName)
            } else {
                Label("inspector.count \(items.count)", systemImage: kind?.symbolName ?? "square.stack")
            }
        }
    }
}

/// Position and size in the chosen unit, and the aspect ratio of a single item.
struct PositionSection: View {
    var store: BoardStore
    var items: [Item]
    @Binding var unit: LengthUnit

    var body: some View {
        let view = Inspection(items: items)
        Section("inspector.position") {
            Picker("inspector.unit", selection: $unit) {
                ForEach(LengthUnit.allCases, id: \.self) { option in
                    Text(LocalizedStringKey(option.symbolKey)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            PositionField(store: store, field: .x, titleKey: "inspector.x", shared: view.x, unit: unit)
            PositionField(store: store, field: .y, titleKey: "inspector.y", shared: view.y, unit: unit)
            PositionField(store: store, field: .width, titleKey: "inspector.width", shared: view.width, unit: unit)
            PositionField(store: store, field: .height, titleKey: "inspector.height", shared: view.height, unit: unit)
            if let ratio = view.ratio {
                LabeledContent("inspector.ratio", value: ratio.text)
                LabeledContent("inspector.ratio.nearest") {
                    Text(LocalizedStringKey(ratio.nearest.nameKey))
                }
            }
        }
    }
}

/// One field of the position. It shows the shared value, or "mixed" when the items differ. Return or leaving the field sets it.
struct PositionField: View {
    var store: BoardStore
    var field: InspectorField
    var titleKey: String
    var shared: SharedValue<Double>
    var unit: LengthUnit

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent(LocalizedStringKey(titleKey)) {
            TextField("", text: $draft, prompt: shared == .mixed ? Text("inspector.mixed") : nil)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onSubmit(commit)
        }
        .onChange(of: shared, initial: true) { draft = text }
        .onChange(of: unit) { draft = text }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
    }

    /// The shared value in the unit, or nothing when the items differ.
    private var text: String { shared.value.map { unit.text(points: $0) } ?? "" }

    /// Sets the field from the draft, but only when the draft was edited: leaving an unchanged field must not
    /// round the value. A draft that is not a number changes nothing.
    private func commit() {
        if draft != text, let points = unit.points(from: draft) {
            _ = try? store.perform(field, to: points)
        }
        draft = text
    }
}

/// The layer, visibility and lock of the selection.
struct LayerSection: View {
    var store: BoardStore
    var items: [Item]

    var body: some View {
        let view = Inspection(items: items)
        let ids = Set(items.map(\.id))
        let layers = store.activeSpace?.layers ?? []
        Section("inspector.layer") {
            Picker("inspector.layer", selection: Binding(
                get: { view.layerID.value ?? "" },
                set: { layerID in _ = try? store.perform(.moveToLayer(ids, layerID: layerID)) }
            )) {
                ForEach(layers) { layer in
                    Text(layer.name).tag(layer.id)
                }
            }
            Toggle("inspector.visible", isOn: Binding(
                get: { view.hidden.value == false },
                set: { visible in _ = try? store.perform(.setHidden(ids, !visible)) }
            ))
            Toggle("inspector.locked", isOn: Binding(
                get: { view.locked.value == true },
                set: { locked in _ = try? store.perform(.setLocked(ids, locked)) }
            ))
        }
    }
}

/// The room, when nothing is selected: its name, the color of the canvas and the grid.
struct RoomSection: View {
    var store: BoardStore
    var snap: SnapSettings

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Section("inspector.room") {
            LabeledContent("inspector.room.name", value: store.activeSpace?.name ?? "")
            LabeledContent("inspector.room.canvas") {
                Rectangle()
                    .fill(theme.color(.background, scheme))
                    .overlay(Rectangle().stroke(theme.color(.border, scheme)))
                    .frame(width: theme.space(.s6), height: theme.space(.s4))
            }
            LabeledContent("inspector.room.grid") {
                if snap.gridStep > 0 {
                    Text("inspector.room.gridStep \(LengthUnit.point.text(points: snap.gridStep))")
                } else {
                    Text("inspector.room.gridOff")
                }
            }
        }
    }
}

extension ItemKind {
    /// The SF Symbol of the kind. It follows the appearance of the system.
    var symbolName: String {
        switch self {
        case .code: "chevron.left.forwardslash.chevron.right"
        case .frame: "iphone"
        case .group: "rectangle.dashed"
        case .image: "photo"
        case .link: "link"
        case .note: "note.text"
        case .shape: "square.on.circle"
        case .swatch: "paintpalette"
        case .text: "textformat"
        }
    }
}
