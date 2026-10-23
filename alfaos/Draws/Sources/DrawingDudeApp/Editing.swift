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

    var rows: Int {
        if case .cabinet = target { return 13 }
        return 4
    }
}

extension DrawsModel {
    static func text(_ value: Double) -> String { String(format: "%g", value) }

    func begin(at point: CGPoint, sheet: Sheet, anchor: CGPoint) -> Bool {
        guard let id = sheet.pick(at: point), let part = parts.first(where: { $0.id == id }) else { return false }
        selected = nil
        if let spot = Locus(id: id, prefix: prefix), beginCabinet(spot, anchor: anchor) { return true }
        editing = Editing(target: .part(id), anchor: anchor, width: Self.text(part.w), height: Self.text(part.h),
                          depth: Self.text(part.d), material: part.material)
        return true
    }

    @discardableResult
    func beginCabinet(_ spot: Locus, anchor: CGPoint) -> Bool {
        guard let spec = kitchen, let pack = kitchenPack, let sizes = try? Kitchen.sizes(spec, pack: pack),
              sizes.indices.contains(spot.run), sizes[spot.run].indices.contains(spot.item) else { return false }
        if !chosen.contains(spot) { chosen = [spot] }
        let cab = spec.all[spot.run].items[spot.item]
        let size = sizes[spot.run][spot.item]
        let shown = cab.fronts.map(Notation.format) ?? (pack.kinds[cab.kind.rawValue]?.front ?? "")
        editing = Editing(target: .cabinet(run: spot.run, item: spot.item), anchor: anchor, width: Self.text(size.width),
                          height: Self.text(size.height), depth: Self.text(size.depth), fronts: shown, first: size, firstFronts: shown)
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
            guard let spec = kitchen else { return }
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
            var final = next
            if h != edit.first.height {
                for other in chosen where other != Locus(run: run, item: item) { final = (try? final.set(other, height: h)) ?? final }
            }
            guard commit(final) else { return }
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
            if case let .cabinet(run, item) = editing.target {
                FieldRow(label: word("draws.edit.fronts"), value: bind(\.fronts), needed: false)
                rows(Locus(run: run, item: item))
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

    @ViewBuilder
    private func rows(_ spot: Locus) -> some View {
        let now = model.resolved(spot)
        let kind = (try? model.kitchen?.cabinet(spot).kind) ?? .base
        Labeled(key: "draws.edit.type") {
            Choice(value: word("draws.cabinet.\(kind.rawValue)")) {
                ForEach(CabinetKind.allCases, id: \.self) { item in
                    Button(word("draws.cabinet.\(item.rawValue)")) { model.retype(item) }
                }
            }
        }
        Labeled(key: "draws.edit.grip") {
            Choice(value: word("draws.grip.\((now?.grip ?? .push).rawValue)")) {
                ForEach(GripStyle.allCases, id: \.self) { item in
                    Button(word("draws.grip.\(item.rawValue)")) { model.apply(.grip(item)) }
                }
            }
        }
        Labeled(key: "draws.edit.style") {
            Choice(value: word("draws.style.\((now?.style ?? .flat).rawValue)")) {
                ForEach(FrontStyle.allCases, id: \.self) { item in
                    Button(word("draws.style.\(item.rawValue)")) { model.apply(.style(item)) }
                }
            }
        }
        Labeled(key: "draws.edit.plinth") {
            Choice(value: word("draws.plinth.\((now?.plinth ?? .panel).rawValue)")) {
                ForEach(PlinthStyle.allCases, id: \.self) { item in
                    Button(word("draws.plinth.\(item.rawValue)")) { model.apply(.plinth(item)) }
                }
            }
        }
        Labeled(key: "draws.edit.edge") {
            Switch(on: Binding(get: { now?.edge ?? false }, set: { model.apply(.edge($0)) }))
        }
        material("draws.edit.front", now?.front) { model.apply(.front($0)) }
        material("draws.edit.carcass", now?.carcass) { model.apply(.carcass($0)) }
        material("draws.edit.worktop", now?.worktop) { model.apply(.worktop($0)) }
        material("draws.edit.plinthMaterial", now?.plinthMaterial) { model.apply(.plinthMaterial($0)) }
    }

    private func material(_ key: String, _ code: String?, _ pick: @escaping (String) -> Void) -> some View {
        Labeled(key: key) {
            Choice(value: model.materialName(code ?? "")) {
                ForEach(model.codes, id: \.self) { item in Button(model.materialName(item)) { pick(item) } }
            }
        }
    }

    private func bind(_ path: WritableKeyPath<Editing, String>) -> Binding<String> {
        Binding(get: { model.editing?[keyPath: path] ?? "" }, set: { model.editing?[keyPath: path] = $0 })
    }
}
