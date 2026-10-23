import AppKit
import DrawingKit
import DrawsAI
import SwiftUI

extension DrawsModel {
    var prefix: String { kitchen?.prefix ?? "" }

    func forgetCabinets() {
        chosen = []
        history = []
        future = []
    }

    func live(_ spot: Locus) -> Bool {
        kitchen.map { $0.spots().contains(spot) } ?? false
    }

    var primary: Locus? { chosen.last }

    func click(_ point: CGPoint, sheet: Sheet, add: Bool) {
        guard kitchen != nil else {
            selected = nil
            return
        }
        if let id = sheet.pick(at: point), let spot = Locus(id: id, prefix: prefix), live(spot) {
            if !add {
                chosen = [spot]
            } else if let at = chosen.firstIndex(of: spot) {
                chosen.remove(at: at)
            } else {
                chosen.append(spot)
            }
        } else if !add {
            chosen = []
            selected = nil
        }
    }

    func rings(in sheet: Sheet) -> [CGRect] {
        var boxes: [CGRect] = []
        for pick in sheet.picks {
            guard let spot = Locus(id: pick.id, prefix: prefix), chosen.contains(spot), !pick.polygon.isEmpty else { continue }
            let xs = pick.polygon.map(\.x), ys = pick.polygon.map(\.y)
            boxes.append(CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0, width: (xs.max() ?? 0) - (xs.min() ?? 0),
                                height: (ys.max() ?? 0) - (ys.min() ?? 0)))
        }
        var merged: [CGRect] = []
        for box in boxes {
            var current = box
            var again = true
            while again {
                again = false
                if let at = merged.firstIndex(where: { $0.insetBy(dx: -Proto.ringInset, dy: -Proto.ringInset).intersects(current) }) {
                    current = current.union(merged.remove(at: at))
                    again = true
                }
            }
            merged.append(current)
        }
        return merged.map { $0.insetBy(dx: -Proto.ringInset, dy: -Proto.ringInset) }
    }

    @discardableResult
    func commit(_ next: KitchenSpec, select spots: [Locus]? = nil) -> Bool {
        guard let pack = kitchenPack else { return false }
        var made = draft()
        do {
            try made.build(next, pack: pack)
        } catch {
            failure = Words.message(error)
            return false
        }
        if let old = kitchen, old != next {
            history.append(old)
            if history.count > Proto.undoDepth { history.removeFirst() }
            future = []
        }
        apply(made)
        if let spots { chosen = spots.filter(live) }
        editing = editing.flatMap { edit in
            if case let .cabinet(run, item) = edit.target, !live(Locus(run: run, item: item)) { return nil }
            return edit
        }
        adopted()
        return true
    }

    private func adopted() {
        let next = draft()
        let toolbox = toolbox
        Task { await toolbox?.adopt(next) }
    }

    private func show(_ spec: KitchenSpec) {
        guard let pack = kitchenPack else { return }
        var made = draft()
        do {
            try made.build(spec, pack: pack)
        } catch {
            failure = Words.message(error)
            return
        }
        apply(made)
        adopted()
    }

    func undo() {
        guard editing == nil else {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
            return
        }
        guard let before = history.popLast(), let now = kitchen else { return }
        future.append(now)
        show(before)
    }

    func redo() {
        guard editing == nil else {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
            return
        }
        guard let after = future.popLast(), let now = kitchen else { return }
        history.append(now)
        show(after)
    }

    func edit(select: ((KitchenSpec) -> [Locus]?)? = nil, _ change: (KitchenSpec, KitchenPack) throws -> KitchenSpec) {
        guard let spec = kitchen, let pack = kitchenPack else { return }
        do {
            let next = try change(spec, pack)
            commit(next, select: select?(next))
        } catch {
            failure = Words.message(error)
        }
    }

    func each(_ step: (KitchenSpec, Locus, KitchenPack) throws -> KitchenSpec) {
        let spots = chosen
        edit { spec, pack in try spots.reduce(spec) { try step($0, $1, pack) } }
    }

    func grow(_ axis: Extent, by delta: Double) {
        each { try $0.resize($1, axis, by: delta, pack: $2) }
    }

    func apply(_ setting: Setting) {
        each { spec, spot, _ in try spec.overriding(spot, setting) }
    }

    func share(_ setting: Setting) {
        edit { spec, _ in try spec.sharing(setting) }
    }

    func reset(_ field: Field? = nil) {
        each { spec, spot, _ in try spec.resetToShared(spot, field) }
    }

    func flip() {
        each { try $0.flipHinge($1, pack: $2) }
    }

    func split(_ split: Split) {
        each { try $0.setSplit($1, split, pack: $2) }
    }

    func retype(_ kind: CabinetKind) {
        each { try $0.setType($1, kind, pack: $2) }
    }

    func insert(_ side: Side) {
        guard let spot = primary, let kind = try? kitchen?.cabinet(spot).kind else { return }
        let target = Locus(run: spot.run, item: spot.item + (side == .after ? 1 : 0))
        edit(select: { _ in [target] }) { spec, _ in try spec.insert(kind, at: spot, side) }
    }

    func duplicate() {
        let spots = chosen.sorted { ($0.run, $0.item) < ($1.run, $1.item) }
        var shift: [Int: Int] = [:]
        var copies: [Locus] = []
        for spot in spots {
            let before = shift[spot.run, default: 0]
            copies.append(Locus(run: spot.run, item: spot.item + before + 1))
            shift[spot.run] = before + 1
        }
        edit(select: { _ in copies }) { spec, _ in
            try spots.reversed().reduce(spec) { try $0.duplicate($1) }
        }
    }

    func remove() {
        let spots = chosen.sorted { ($0.run, $0.item) > ($1.run, $1.item) }
        guard let last = spots.last else { return }
        edit(select: { spec in
            let count = spec.all.indices.contains(last.run) ? spec.all[last.run].items.count : 0
            return count == 0 ? [] : [Locus(run: last.run, item: min(last.item, count - 1))]
        }) { spec, _ in try spots.reduce(spec) { try $0.remove($1) } }
    }

    func move(_ step: Step) {
        guard let spot = primary, let target = kitchen?.moveTarget(spot, step) else { return }
        edit(select: { _ in [target] }) { spec, _ in try spec.move(spot, step) }
    }

    func neighbour(_ step: Step) {
        guard let spot = primary, let spec = kitchen else {
            if let first = kitchen?.spots().first { chosen = [first] }
            return
        }
        let count = spec.all[spot.run].items.count
        let next = spot.item + (step == .left ? -1 : 1)
        if (0..<count).contains(next) { chosen = [Locus(run: spot.run, item: next)] }
    }

    func key(_ press: KeyPress, open: (Locus) -> Void) -> KeyPress.Result {
        guard kitchen != nil, editing == nil else { return .ignored }
        let command = press.modifiers.contains(.command), option = press.modifiers.contains(.option)
        let step = press.modifiers.contains(.shift) ? Proto.stepFine : Proto.stepCoarse
        let side: Step? = press.key == .leftArrow ? .left : press.key == .rightArrow ? .right : nil
        if press.key == .escape {
            guard !chosen.isEmpty else { return .ignored }
            chosen = []
            return .handled
        }
        if command, press.characters.lowercased() == "d", !chosen.isEmpty {
            duplicate()
            return .handled
        }
        guard !chosen.isEmpty else { return .ignored }
        switch press.key {
        case .delete, .deleteForward: remove()
        case .return: if let spot = primary { open(spot) }
        case .leftArrow, .rightArrow:
            guard let side else { return .ignored }
            if command { grow(.width, by: side == .left ? -step : step) } else if option { move(side) } else { neighbour(side) }
        case .upArrow, .downArrow:
            guard command else { return .ignored }
            grow(.height, by: press.key == .upArrow ? step : -step)
        default: return .ignored
        }
        return .handled
    }

    func resolved(_ spot: Locus? = nil) -> Resolved? {
        guard let spec = kitchen, let pack = kitchenPack else { return nil }
        let cab = spot.flatMap { try? spec.cabinet($0) } ?? Cabinet(kind: .base)
        return spec.resolve(cab, pack: pack)
    }
}
