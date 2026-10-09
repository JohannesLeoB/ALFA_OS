import Foundation
import ALFAcolorCore

/// The result of one command on the item list of a space.
struct StepResult {
    var items: [Item]
    /// IDs of all items that were added, removed or changed.
    var touched: Set<ItemID>
    var selection: Set<ItemID>
}

/// Reads one space and runs the commands that change its items. It never changes the board itself.
struct StepScope {
    let board: Board
    let space: Space
    private let position: [ItemID: Int]
    private let layerIDs: Set<String>
    private let lockedLayers: Set<String>

    init(board: Board, spaceIndex: Int) {
        self.board = board
        space = board.spaces[spaceIndex]
        position = Dictionary(space.items.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        layerIDs = Set(space.layers.map(\.id))
        lockedLayers = Set(space.layers.filter(\.locked).map(\.id))
    }

    // MARK: Lookup

    func item(_ id: ItemID) throws -> Item {
        guard let index = position[id] else { throw CommandError.unknownItem(id) }
        return space.items[index]
    }

    /// The items with these IDs, in the order of the space.
    func items(_ ids: Set<ItemID>) throws -> [Item] {
        for id in ids where position[id] == nil { throw CommandError.unknownItem(id) }
        return ids.compactMap { position[$0] }.sorted().map { space.items[$0] }
    }

    func isEditable(_ item: Item) -> Bool { !item.locked && !lockedLayers.contains(item.layerID) }

    private func editable(_ ids: Set<ItemID>) throws -> [Item] { try items(ids).filter(isEditable) }

    /// The items that move when these move: the items themselves, plus the editable items inside frames and groups.
    private func withChildren(_ moving: [Item]) -> [ItemID: Item] {
        var out = Dictionary(uniqueKeysWithValues: moving.map { ($0.id, $0) })
        for container in moving where container.isContainer {
            for child in children(of: container, in: space.items) where isEditable(child) && out[child.id] == nil {
                out[child.id] = child
            }
        }
        return out
    }

    private static func isValid(_ rect: Rect) -> Bool {
        [rect.x, rect.y, rect.w, rect.h].allSatisfy(\.isFinite) && rect.w >= 0 && rect.h >= 0
    }

    private static func isGroup(_ item: Item) -> Bool {
        if case .group = item.content { return true }
        return false
    }

    // MARK: Commands

    func run(_ command: Command, selection: Set<ItemID>) throws -> StepResult? {
        var out = StepResult(items: space.items, touched: [], selection: selection)
        switch command {
        case .insert(let new): try insert(new, into: &out)
        case .delete(let ids): try delete(ids, into: &out)
        case .move(let ids, let dx, let dy): try move(ids, dx: dx, dy: dy, into: &out)
        case .resize(let rects): try resize(rects, into: &out)
        case .reorder(let ids, let how): try reorder(ids, how, into: &out)
        case .setContent(let id, let content): try setContent(id, content, into: &out)
        case .setFill(let ids, let hex): try setFill(ids, hex: hex, into: &out)
        case .setSource(let id, let source): try setSource(id, source, into: &out)
        case .group(let ids, let title, let groupID): try group(ids, title: title, groupID: groupID, into: &out)
        case .ungroup(let ids): try ungroup(ids, into: &out)
        case .setLocked(let ids, let value):
            try setFlag(ids, into: &out) { item in
                guard item.locked != value else { return false }
                item.locked = value
                return true
            }
        case .setHidden(let ids, let value):
            try setFlag(ids, into: &out) { item in
                guard item.hidden != value else { return false }
                item.hidden = value
                return true
            }
        case .moveToLayer(let ids, let layerID): try moveToLayer(ids, layerID: layerID, into: &out)
        case .arrange(let how, let ids, let reference, let options):
            try arrange(how, ids, reference: reference, options: options, into: &out)
        case .switchSpace, .batch: return nil
        }
        return out.touched.isEmpty ? nil : out
    }

    private func insert(_ new: [Item], into out: inout StepResult) throws {
        var taken = Set(board.spaces.flatMap(\.items).map(\.id))
        for item in new {
            guard taken.insert(item.id).inserted else { throw CommandError.duplicateItem(item.id) }
            guard layerIDs.contains(item.layerID) else { throw CommandError.unknownLayer(item.layerID) }
            guard Self.isValid(item.rect) else { throw CommandError.invalidGeometry }
        }
        out.items += new
        out.touched = Set(new.map(\.id))
        out.selection = out.touched
    }

    private func delete(_ ids: Set<ItemID>, into out: inout StepResult) throws {
        let doomed = Set(try editable(ids).map(\.id))
        out.items.removeAll { doomed.contains($0.id) }
        out.touched = doomed
        out.selection.subtract(doomed)
    }

    private func shift(_ moving: some Collection<ItemID>, dx: Double, dy: Double, into out: inout StepResult) {
        for id in moving {
            guard let index = position[id] else { continue }
            out.items[index].rect.x += dx
            out.items[index].rect.y += dy
            out.touched.insert(id)
        }
    }

    private func move(_ ids: Set<ItemID>, dx: Double, dy: Double, into out: inout StepResult) throws {
        guard dx.isFinite, dy.isFinite else { throw CommandError.invalidGeometry }
        let moving = withChildren(try editable(ids))
        guard dx != 0 || dy != 0 else { return }
        shift(moving.keys, dx: dx, dy: dy, into: &out)
    }

    private func resize(_ rects: [ItemID: Rect], into out: inout StepResult) throws {
        for (id, rect) in rects {
            let target = try item(id)
            guard Self.isValid(rect) else { throw CommandError.invalidGeometry }
            guard isEditable(target), let index = position[id] else { continue }
            out.items[index].rect = rect
            out.touched.insert(id)
        }
    }

    private func reorder(_ ids: Set<ItemID>, _ how: StackMove, into out: inout StepResult) throws {
        let chosen = try editable(ids)
        for layerID in Set(chosen.map(\.layerID)) {
            let picked = Set(chosen.filter { $0.layerID == layerID }.map(\.id))
            let stack = space.items.indices.filter { space.items[$0].layerID == layerID }
                .sorted { (space.items[$0].z, $0) < (space.items[$1].z, $1) }
            let order = stack.map { space.items[$0].id }
            var flags = order.map { picked.contains($0) }
            var next = order
            switch how {
            case .toFront: next = order.filter { !picked.contains($0) } + order.filter { picked.contains($0) }
            case .toBack: next = order.filter { picked.contains($0) } + order.filter { !picked.contains($0) }
            case .forward:
                for i in stride(from: order.count - 2, through: 0, by: -1) where flags[i] && !flags[i + 1] {
                    next.swapAt(i, i + 1)
                    flags.swapAt(i, i + 1)
                }
            case .backward:
                for i in stride(from: 1, to: order.count, by: 1) where flags[i] && !flags[i - 1] {
                    next.swapAt(i, i - 1)
                    flags.swapAt(i, i - 1)
                }
            }
            guard next != order, let base = stack.map({ space.items[$0].z }).min() else { continue }
            for (rank, id) in next.enumerated() {
                guard let index = position[id], out.items[index].z != base + rank else { continue }
                out.items[index].z = base + rank
                out.touched.insert(id)
            }
        }
    }

    private func group(_ ids: Set<ItemID>, title: String, groupID: ItemID, into out: inout StepResult) throws {
        let members = try editable(ids).filter { !Self.isGroup($0) }
        guard let first = members.first else { return }
        guard !board.spaces.contains(where: { $0.items.contains { $0.id == groupID } }) else { throw CommandError.duplicateItem(groupID) }
        let minX = members.map(\.rect.x).min()!, minY = members.map(\.rect.y).min()!
        let maxX = members.map(\.rect.maxX).max()!, maxY = members.map(\.rect.maxY).max()!
        let below = members.filter { $0.layerID == first.layerID }.map(\.z).min()! - 1
        let made = Item(id: groupID, title: title, content: .group(title: title),
                        rect: Rect(x: minX, y: minY, w: maxX - minX, h: maxY - minY), z: below, layerID: first.layerID)
        out.items.append(made)
        out.touched = [groupID]
        out.selection = [groupID]
    }

    private func ungroup(_ ids: Set<ItemID>, into out: inout StepResult) throws {
        let groups = try editable(ids).filter(Self.isGroup)
        let doomed = Set(groups.map(\.id))
        guard !doomed.isEmpty else { return }
        var freed = Set<ItemID>()
        for group in groups { freed.formUnion(children(of: group, in: space.items).map(\.id)) }
        out.items.removeAll { doomed.contains($0.id) }
        out.touched = doomed
        out.selection = freed.subtracting(doomed)
    }

    private func setContent(_ id: ItemID, _ content: Content, into out: inout StepResult) throws {
        let target = try item(id)
        guard isEditable(target), target.content != content, let index = position[id] else { return }
        out.items[index].content = content
        out.touched.insert(id)
    }

    private func setSource(_ id: ItemID, _ source: Source?, into out: inout StepResult) throws {
        let target = try item(id)
        guard isEditable(target), target.source != source, let index = position[id] else { return }
        out.items[index].source = source
        out.touched.insert(id)
    }

    private func setFill(_ ids: Set<ItemID>, hex: String, into out: inout StepResult) throws {
        for target in try editable(ids) {
            guard let index = position[target.id], let content = Self.painted(target.content, hex: hex) else { continue }
            out.items[index].content = content
            out.touched.insert(target.id)
        }
    }

    /// The content with a new colour. Nil for an item without a colour, and for a colour it already has.
    private static func painted(_ content: Content, hex: String) -> Content? {
        switch content {
        case .shape(let kind, let style):
            var next = style
            if kind == .line { next.stroke = hex } else { next.fill = hex }
            return next == style ? nil : .shape(kind: kind, style: next)
        case .swatch(let current, _):
            return current == hex ? nil : .swatch(hex: hex, name: nil)
        default:
            return nil
        }
    }

    private func setFlag(_ ids: Set<ItemID>, into out: inout StepResult, change: (inout Item) -> Bool) throws {
        for target in try items(ids) {
            guard let index = position[target.id] else { continue }
            if change(&out.items[index]) { out.touched.insert(target.id) }
        }
    }

    private func moveToLayer(_ ids: Set<ItemID>, layerID: String, into out: inout StepResult) throws {
        guard layerIDs.contains(layerID) else { throw CommandError.unknownLayer(layerID) }
        for target in try editable(ids) where target.layerID != layerID {
            guard let index = position[target.id] else { continue }
            out.items[index].layerID = layerID
            out.touched.insert(target.id)
        }
    }

    private func arrange(_ how: Arrangement, _ ids: Set<ItemID>, reference: ItemID?, options: ArrangeOptions, into out: inout StepResult) throws {
        let chosen = try editable(ids)
        let rects = ALFAcolorCore.arrange(chosen, how, reference: reference, options: options)
        var carried = Set(chosen.map(\.id))
        var follow: [(container: Item, dx: Double, dy: Double)] = []
        for target in chosen {
            guard let rect = rects[target.id], rect != target.rect, let index = position[target.id] else { continue }
            out.items[index].rect = rect
            out.touched.insert(target.id)
            if target.isContainer { follow.append((target, rect.x - target.rect.x, rect.y - target.rect.y)) }
        }
        for step in follow where step.dx != 0 || step.dy != 0 {
            let inside = children(of: step.container, in: space.items).filter { isEditable($0) && carried.insert($0.id).inserted }
            shift(inside.map(\.id), dx: step.dx, dy: step.dy, into: &out)
        }
    }
}
