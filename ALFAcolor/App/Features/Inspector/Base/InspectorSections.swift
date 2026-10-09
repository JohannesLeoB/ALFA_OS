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
        let selection = Set(items.map(\.id))
        Section("inspector.position") {
            Picker("inspector.unit", selection: $unit) {
                ForEach(LengthUnit.allCases, id: \.self) { option in
                    Text(LocalizedStringKey(option.symbolKey)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            PositionField(store: store, field: .x, titleKey: "inspector.x", shared: view.x, unit: unit, selection: selection)
            PositionField(store: store, field: .y, titleKey: "inspector.y", shared: view.y, unit: unit, selection: selection)
            PositionField(store: store, field: .width, titleKey: "inspector.width", shared: view.width, unit: unit, selection: selection)
            PositionField(store: store, field: .height, titleKey: "inspector.height", shared: view.height, unit: unit, selection: selection)
            if let ratio = view.ratio {
                LabeledContent(LocalizedStringKey("inspector.ratio")) {
                    RollingText(text: ratio.text)
                }
                LabeledContent("inspector.ratio.nearest") {
                    Text(LocalizedStringKey(ratio.nearest.nameKey))
                }
            }
        }
    }
}

/// One field of the position. It shows the shared value, or "mixed" when the items differ.
/// Return or leaving the field sets it. A draft that is not a number stays and is marked red.
/// A draft belongs to the selection it was typed for: when the selection changes, the draft is dropped.
struct PositionField: View {
    var store: BoardStore
    var field: InspectorField
    var titleKey: String
    var shared: SharedValue<Double>
    var unit: LengthUnit
    /// The items the field shows. Compared on every change, so that a draft never reaches other items.
    var selection: Set<ItemID>

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var draft = ""
    /// The text the field showed when it was last synced. A draft that differs from it was typed by the user.
    @State private var synced = ""
    @State private var invalid = false
    /// True when the value is a number, but the items keep their size or place (for example a locked item).
    @State private var blocked = false
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent(LocalizedStringKey(titleKey)) {
            TextField("", text: $draft, prompt: shared == .mixed ? Text("inspector.mixed") : nil)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(invalid || blocked ? theme.color(.coral, scheme) : theme.color(.text, scheme))
                .focused($focused)
                .onSubmit(commit)
                .help(invalid ? "inspector.invalid" : blocked ? "inspector.field.blocked" : "")
        }
        .onChange(of: shared, initial: true) { if draft == synced { sync() } }
        .onChange(of: selection) { old, _ in
            // A draft typed before the selection changed is applied to the items it was typed for.
            if draft != synced, let points = unit.points(from: draft) {
                _ = try? store.perform(field, to: points, on: old)
            }
            sync()
        }
        .onChange(of: unit) { sync() }
        .onChange(of: draft) { invalid = false; blocked = false }
        .onChange(of: focused) { _, isFocused in
            // While the field has focus, a room change applies the draft first (see BoardStore.pendingDraft).
            store.pendingDraft = isFocused ? { commit() } : nil
            if !isFocused { commit() }
        }
    }

    /// The shared value in the unit, or nothing when the items differ.
    private var text: String { shared.value.map { unit.text(points: $0) } ?? "" }

    /// Shows the shared value again and drops the draft.
    private func sync() {
        synced = text
        draft = text
        invalid = false
    }

    /// Sets the field from the draft, but only when the draft was edited: leaving an unchanged field must not
    /// round the value. A draft that is not a number is kept and marked.
    private func commit() {
        guard draft != text else { return }
        guard let points = unit.points(from: draft) else {
            invalid = true
            return
        }
        let changed = (try? store.perform(field, to: points)) ?? false
        // A number that the items refuse to take stays in the field, marked, instead of vanishing.
        if !changed, shared.value != points {
            blocked = true
            return
        }
        sync()
    }
}

/// The layer, visibility and lock of the selection. Values that differ are shown as "mixed".
struct LayerSection: View {
    var store: BoardStore
    var items: [Item]

    var body: some View {
        let view = Inspection(items: items)
        let ids = Set(items.map(\.id))
        let layers = store.activeSpace?.layers ?? []
        Section("inspector.layer") {
            Picker("inspector.layer", selection: Binding<String?>(
                get: { view.layerID.value },
                set: { layerID in
                    if let layerID { _ = try? store.perform(.moveToLayer(ids, layerID: layerID)) }
                }
            )) {
                if view.layerID == .mixed { Text("inspector.mixed").tag(String?.none) }
                ForEach(layers) { layer in
                    Text(layer.name).tag(Optional(layer.id))
                }
            }
            Picker("inspector.visible", selection: Binding<Bool?>(
                get: { view.hidden.value.map { !$0 } },
                set: { visible in
                    if let visible { _ = try? store.perform(.setHidden(ids, !visible)) }
                }
            )) {
                if view.hidden == .mixed { Text("inspector.mixed").tag(Bool?.none) }
                Text("inspector.visible.shown").tag(Optional(true))
                Text("inspector.visible.hidden").tag(Optional(false))
            }
            Picker("inspector.locked", selection: Binding<Bool?>(
                get: { view.locked.value },
                set: { locked in
                    if let locked { _ = try? store.perform(.setLocked(ids, locked)) }
                }
            )) {
                if view.locked == .mixed { Text("inspector.mixed").tag(Bool?.none) }
                Text("inspector.locked.yes").tag(Optional(true))
                Text("inspector.locked.no").tag(Optional(false))
            }
        }
    }
}

/// The room, when nothing is selected: its name, the color of the canvas and the grid.
struct RoomSection: View {
    var store: BoardStore
    var snap: SnapSettings
    var interaction: CanvasInteraction

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
            Toggle("inspector.room.distances", isOn: Binding(
                get: { interaction.showsDistances },
                set: { interaction.showsDistances = $0 }
            ))
            Toggle("inspector.room.snapSpacing", isOn: Binding(
                get: { interaction.snap.snapsToSpacing },
                set: { interaction.snap.snapsToSpacing = $0 }
            ))
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

/// The zone colour of the selected groups: one of the seven zone colours, picked with the mouse.
struct ZoneSection: View {
    var store: BoardStore
    var items: [Item]

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    /// Names of the zone colours for screen readers, by token name.
    private static let names: [String: String] = [
        "zone-stein": "zone.color.stone", "zone-pflaume": "zone.color.plum", "zone-nacht": "zone.color.night",
        "zone-aprikose": "zone.color.apricot", "zone-rose": "zone.color.rose", "zone-papier": "zone.color.paper",
        "zone-schwarz": "zone.color.black",
    ]

    var body: some View {
        let tints = SharedValue(items.compactMap { item -> String? in
            guard case .group(_, let tint) = item.content else { return nil }
            return ZoneTint.token(named: tint).rawValue
        })
        Section("item.kind.group") {
            HStack(spacing: theme.space(.s2)) {
                ForEach(ZoneTint.all, id: \.self) { zone in
                    let chosen = tints.value == zone.rawValue
                    Button {
                        _ = try? store.perform(groupTint: zone.rawValue)
                    } label: {
                        Rectangle()
                            .fill(theme.color(zone, scheme))
                            .overlay(Rectangle().strokeBorder(theme.color(chosen ? .coral : .border, scheme), lineWidth: chosen ? 2 : 1))
                            .frame(width: theme.space(.s5), height: theme.space(.s5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(LocalizedStringKey(Self.names[zone.rawValue] ?? "zone.color.paper"))
                }
            }
        }
    }
}
