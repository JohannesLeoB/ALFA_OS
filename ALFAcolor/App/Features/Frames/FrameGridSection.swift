import SwiftUI
import ALFAcolorCore
import BoardModel
import Geometry

/// The column grid of the selected frames: on or off, columns, gutter, margins and baselines.
/// A value that the frames do not share shows "mixed". A change sets the whole grid, taken from the
/// first frame that has one, on every selected frame.
struct FrameGridSection: View {
    var store: BoardStore
    var items: [Item]

    @State private var separateMargins = false
    @State private var templates: [GridTemplate] = []

    var body: some View {
        let grids = self.grids
        let on = SharedValue(grids.map { $0 != nil })
        Toggle("inspector.frame.grid", isOn: Binding(
            get: { on.value == true },
            set: { isOn in
                if isOn {
                    _ = try? store.perform(frameGrid: grids.compactMap { $0 }.first ?? FrameGrid.standard)
                } else {
                    _ = try? store.performFrameGridRemoval()
                }
            }))
            .onAppear(perform: reload)
        if grids.contains(where: { $0 != nil }) {
            GridNumberField(titleKey: "inspector.frame.columns", shared: shared(grids) { Double($0.columns) }) { value in
                apply { $0.columns = max(1, value.clampedInt) }
            }
            GridNumberField(titleKey: "inspector.frame.gutter", shared: shared(grids) { $0.gutter }) { value in
                apply { $0.gutter = value }
            }
            Toggle("inspector.frame.margin.separate", isOn: $separateMargins)
            if separateMargins {
                GridNumberField(titleKey: "inspector.frame.margin.top", shared: shared(grids) { $0.marginTop }) { value in
                    apply { $0.marginTop = value }
                }
                GridNumberField(titleKey: "inspector.frame.margin.bottom", shared: shared(grids) { $0.marginBottom }) { value in
                    apply { $0.marginBottom = value }
                }
                GridNumberField(titleKey: "inspector.frame.margin.left", shared: shared(grids) { $0.marginLeft }) { value in
                    apply { $0.marginLeft = value }
                }
                GridNumberField(titleKey: "inspector.frame.margin.right", shared: shared(grids) { $0.marginRight }) { value in
                    apply { $0.marginRight = value }
                }
            } else {
                GridNumberField(titleKey: "inspector.frame.margin", shared: shared(grids) { $0.marginLeft }) { value in
                    apply {
                        $0.marginLeft = value; $0.marginRight = value
                        $0.marginTop = value; $0.marginBottom = value
                    }
                }
            }
            GridNumberField(titleKey: "inspector.frame.baseline", shared: shared(grids) { $0.baseline }) { value in
                apply { $0.baseline = max(0, value) }
            }
            GridNumberField(titleKey: "inspector.frame.baselineStart", shared: shared(grids) { $0.baselineStart }) { value in
                apply { $0.baselineStart = max(0, value) }
            }
            Menu("inspector.frame.template") {
                Button("inspector.frame.template.save", action: saveTemplate)
                if !templates.isEmpty {
                    Divider()
                    ForEach(templates) { template in
                        Button(template.name) { applyTemplate(template) }
                    }
                    Menu("inspector.frame.template.delete") {
                        ForEach(templates) { template in
                            Button(template.name) { deleteTemplate(template) }
                        }
                    }
                }
            }
        }
    }

    private func reload() {
        templates = (try? GridTemplates.load(from: GridTemplateFile.url())) ?? []
    }

    /// Saves the grid of the first frame that has one. The name gives its columns and gutter.
    private func saveTemplate() {
        guard let grid = grids.compactMap({ $0 }).first, let url = try? GridTemplateFile.url() else { return }
        let columns = grid.columns
        let gutter = grid.gutter.clampedInt
        let name = String(localized: "grid.template.name \(columns) \(gutter)")
        try? GridTemplates.add(GridTemplate(name: name, grid: grid), to: url)
        reload()
    }

    /// Sets the grid of the template on every selected frame. One undo step.
    private func applyTemplate(_ template: GridTemplate) {
        _ = try? store.perform(frameGrid: template.grid)
    }

    private func deleteTemplate(_ template: GridTemplate) {
        guard let url = try? GridTemplateFile.url() else { return }
        try? GridTemplates.remove(id: template.id, from: url)
        reload()
    }

    /// The grid of each selected frame, nil for a frame without a grid.
    private var grids: [ColumnGrid?] {
        items.map { item -> ColumnGrid? in
            guard case .frame(_, _, _, let grid, _) = item.content else { return nil }
            return grid
        }
    }

    /// The value of one grid property, shared by the frames that have a grid. nil shows "mixed" when they differ.
    private func shared(_ grids: [ColumnGrid?], _ value: (ColumnGrid) -> Double) -> SharedValue<Double> {
        SharedValue(grids.compactMap { $0.map(value) })
    }

    /// Changes the first grid of the selection and sets the result on every selected frame. One undo step.
    private func apply(_ edit: (inout ColumnGrid) -> Void) {
        guard var grid = grids.compactMap({ $0 }).first else { return }
        edit(&grid)
        _ = try? store.perform(frameGrid: grid)
    }
}

/// One number of the grid. It shows the shared value, or "mixed" when the frames differ.
/// Return or leaving the field sets it. A text that is not a number is dropped and the value shows again.
struct GridNumberField: View {
    var titleKey: String
    var shared: SharedValue<Double>
    var commit: (Double) -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent(LocalizedStringKey(titleKey)) {
            TextField("", text: $draft, prompt: shared == .mixed ? Text("inspector.mixed") : nil)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onSubmit(send)
        }
        .onChange(of: shared, initial: true) { draft = Self.text(shared.value) }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { send() }
        }
    }

    private func send() {
        if let number = Double(draft.replacingOccurrences(of: ",", with: ".")), number.isFinite {
            commit(number)
        }
        draft = Self.text(shared.value)
    }

    /// The number with up to two decimals, with a point as the decimal sign so that it parses back.
    private static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US_POSIX")))
    }
}
