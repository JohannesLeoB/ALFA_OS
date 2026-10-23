import DrawingKit
import DrawsAI
import ShellCore
import SwiftUI

struct Editing: Equatable {
    enum Target: Equatable {
        case cabinet(run: Int, item: Int)
        case part(String)
    }

    var target: Target
    var anchor: CGPoint
    var width = ""
    var height = ""
    var depth = ""
    var fronts = ""
    var material = ""
    var first = Kitchen.Size(width: 0, height: 0, depth: 0)
    var firstFronts = ""
}

extension DrawsModel {
    static func text(_ value: Double) -> String { String(format: "%g", value) }

    func begin(at point: CGPoint, sheet: Sheet, anchor: CGPoint) -> Bool {
        guard let id = sheet.pick(at: point), let part = parts.first(where: { $0.id == id }) else { return false }
        selected = nil
        if let spec = kitchen, let pack = kitchenPack, let slot = Kitchen.slot(id, prefix: spec.prefix ?? ""), let item = slot.item,
           let sizes = try? Kitchen.sizes(spec, pack: pack), sizes.indices.contains(slot.run), sizes[slot.run].indices.contains(item) {
            let cab = spec.all[slot.run].items[item]
            let size = sizes[slot.run][item]
            let shown = cab.fronts.map(Notation.format) ?? (pack.kinds[cab.kind.rawValue]?.front ?? "")
            editing = Editing(target: .cabinet(run: slot.run, item: item), anchor: anchor, width: Self.text(size.width),
                              height: Self.text(size.height), depth: Self.text(size.depth), fronts: shown, first: size, firstFronts: shown)
        } else {
            editing = Editing(target: .part(id), anchor: anchor, width: Self.text(part.w), height: Self.text(part.h),
                              depth: Self.text(part.d), material: part.material)
        }
        return true
    }

    func cancelEdit() { editing = nil }

    private func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
            .flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    func commitEdit() {
        guard let edit = editing else { return }
        guard let w = number(edit.width), let h = number(edit.height), let d = number(edit.depth) else {
            failure = Words.message(KitchenError.size("", "size"))
            return
        }
        switch edit.target {
        case let .cabinet(run, item):
            guard let spec = kitchen, let pack = kitchenPack else { return }
            var fronts: [Front]?
            var changed = false
            if edit.fronts != edit.firstFronts {
                let text = edit.fronts.trimmingCharacters(in: .whitespaces)
                if text.isEmpty || text == "none" {
                    fronts = []
                } else if let parsed = Notation.parse(text) {
                    fronts = parsed
                } else {
                    failure = Words.message(KitchenError.unknown("", edit.fronts))
                    return
                }
                changed = true
            }
            let next = spec.with(run: run, item: item) { cab in
                if w != edit.first.width || cab.width != nil { cab.width = w }
                if h != edit.first.height || cab.height != nil { cab.height = h }
                if d != edit.first.depth || cab.depth != nil { cab.depth = d }
                if changed { cab.fronts = fronts }
            }
            var draft = draft()
            do {
                try draft.build(next, pack: pack)
            } catch {
                failure = Words.message(error)
                return
            }
            apply(draft)
        case let .part(id):
            guard let index = parts.firstIndex(where: { $0.id == id }) else { return }
            var part = parts[index]
            part.w = w; part.h = h; part.d = d
            let code = edit.material.trimmingCharacters(in: .whitespaces)
            if !code.isEmpty { part.material = code }
            parts[index] = part
        }
        editing = nil
        let next = draft()
        let live = toolbox
        Task { await live?.adopt(next) }
    }
}

struct InlineEditor: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel
    let editing: Editing
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.contextMenu))
        VStack(spacing: 0) {
            FieldRow(label: word("draws.edit.width"), value: bind(\.width), needed: false)
            FieldRow(label: word("draws.edit.height"), value: bind(\.height), needed: false)
            FieldRow(label: word("draws.edit.depth"), value: bind(\.depth), needed: false)
            if case .cabinet = editing.target {
                FieldRow(label: word("draws.edit.fronts"), value: bind(\.fronts), needed: false)
            } else {
                FieldRow(label: word("draws.edit.material"), value: bind(\.material), needed: false)
            }
        }
        .padding(CGFloat(Design.Spacing.step4))
        .frame(width: CGFloat(Proto.editorWidth))
        .background(shape.fill(style.color(\.menu)))
        .shadowed(style, style.shadow(\.floating), shape)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onSubmit { model.commitEdit() }
        .onKeyPress(.return) { model.commitEdit(); return .handled }
        .onKeyPress(.escape) { model.cancelEdit(); return .handled }
        .onExitCommand { model.cancelEdit() }
    }

    private func bind(_ path: WritableKeyPath<Editing, String>) -> Binding<String> {
        Binding(get: { model.editing?[keyPath: path] ?? "" }, set: { model.editing?[keyPath: path] = $0 })
    }
}
