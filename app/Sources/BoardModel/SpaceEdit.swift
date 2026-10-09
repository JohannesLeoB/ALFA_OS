import Foundation
import ALFAcolorCore

/// Why a change of the rooms, the layers or the items between rooms was refused.
public enum SpaceError: Error, Equatable, Sendable {
    case unknownSpace(String)
    case unknownLayer(String)
    case duplicateSpace(String)
    case duplicateItem(ItemID)
    case duplicateLayer(String)
    case lastSpace
    case lastLayer
    case emptyName
    case invalidPosition
}

/// Changes to the rooms (spaces), their layers and the items that move between rooms.
/// They work on a board value. `BoardStore.changeBoard` runs them and gives one undo step.
extension Board {
    /// A room ID that no room uses yet: `base`, then `base-2`, `base-3` and so on.
    public func freeSpaceID(base: String = "room") -> String {
        var number = 1
        while true {
            let candidate = number == 1 ? base : "\(base)-\(number)"
            if !spaces.contains(where: { $0.id == candidate }) { return candidate }
            number += 1
        }
    }

    /// The first name of the form `template` (for example "Raum %lld") that no room has, counting from 2.
    /// The first room keeps its own name, so the numbers start at 2.
    public func freeSpaceName(template: String) -> String {
        var number = 2
        while true {
            let candidate = String(format: template, number)
            if !spaces.contains(where: { $0.name == candidate }) { return candidate }
            number += 1
        }
    }

    /// A layer ID that no layer of the room uses yet: `base`, then `base-2` and so on.
    public func freeLayerID(base: String = "layer", in spaceID: String) -> String {
        let used = Set(spaces.first { $0.id == spaceID }?.layers.map(\.id) ?? [])
        var number = 1
        while true {
            let candidate = number == 1 ? base : "\(base)-\(number)"
            if !used.contains(candidate) { return candidate }
            number += 1
        }
    }

    /// Adds a layer on top of the stack of a room. The name is trimmed; an empty name or a used ID is refused.
    @discardableResult
    public mutating func addLayer(id: String, name: String, in spaceID: String) throws -> Layer {
        let name = try Self.cleanName(name)
        let space = try spaceIndex(spaceID)
        guard !spaces[space].layers.contains(where: { $0.id == id }) else { throw SpaceError.duplicateLayer(id) }
        let layer = Layer(id: id, name: name)
        spaces[space].layers.append(layer)
        return layer
    }

    /// Gives a layer another name. The name is trimmed; an empty name is refused.
    public mutating func renameLayer(_ layer: String, to name: String, in spaceID: String) throws {
        let name = try Self.cleanName(name)
        let (space, index) = try layerIndex(layer, in: spaceID)
        spaces[space].layers[index].name = name
    }

    /// Removes a layer. Its items move to the layer below it, or to the first layer left.
    /// The last layer of a room cannot be removed.
    public mutating func removeLayer(_ layer: String, in spaceID: String) throws {
        let (space, index) = try layerIndex(layer, in: spaceID)
        guard spaces[space].layers.count > 1 else { throw SpaceError.lastLayer }
        spaces[space].layers.remove(at: index)
        let fallback = index > 0 ? spaces[space].layers[index - 1].id : spaces[space].layers[0].id
        for item in spaces[space].items.indices where spaces[space].items[item].layerID == layer {
            spaces[space].items[item].layerID = fallback
        }
    }

    /// Adds an empty room at the end. The name is trimmed; an empty name or a used ID is refused.
    @discardableResult
    public mutating func addSpace(id: String, name: String) throws -> Space {
        let name = try Self.cleanName(name)
        guard !spaces.contains(where: { $0.id == id }) else { throw SpaceError.duplicateSpace(id) }
        let space = Space(id: id, name: name)
        spaces.append(space)
        return space
    }

    /// Gives a room another name. The name is trimmed; an empty name is refused.
    public mutating func renameSpace(_ id: String, to name: String) throws {
        let name = try Self.cleanName(name)
        spaces[try spaceIndex(id)].name = name
    }

    /// Moves a room to another place in the tab order.
    public mutating func moveSpace(_ id: String, to position: Int) throws {
        let index = try spaceIndex(id)
        guard spaces.indices.contains(position) else { throw SpaceError.invalidPosition }
        let space = spaces.remove(at: index)
        spaces.insert(space, at: position)
    }

    /// Removes a room with all its items. The last room cannot be removed.
    public mutating func removeSpace(_ id: String) throws {
        let index = try spaceIndex(id)
        guard spaces.count > 1 else { throw SpaceError.lastSpace }
        spaces.remove(at: index)
    }

    /// True when the room has items. The view asks before it closes such a room.
    public func spaceHasContent(_ id: String) -> Bool {
        !(spaces.first { $0.id == id }?.items.isEmpty ?? true)
    }

    /// Shows or hides a layer. Its items stay where they are.
    public mutating func setLayerVisible(_ visible: Bool, layer: String, in spaceID: String) throws {
        let (space, index) = try layerIndex(layer, in: spaceID)
        spaces[space].layers[index].visible = visible
    }

    /// Locks or unlocks a layer. Items on a locked layer are skipped by every command except hiding.
    public mutating func setLayerLocked(_ locked: Bool, layer: String, in spaceID: String) throws {
        let (space, index) = try layerIndex(layer, in: spaceID)
        spaces[space].layers[index].locked = locked
    }

    /// Moves a layer to another place in the stack of the room.
    public mutating func moveLayer(_ layer: String, to position: Int, in spaceID: String) throws {
        let (space, index) = try layerIndex(layer, in: spaceID)
        guard spaces[space].layers.indices.contains(position) else { throw SpaceError.invalidPosition }
        let moved = spaces[space].layers.remove(at: index)
        spaces[space].layers.insert(moved, at: position)
    }

    /// The number of items on a layer of a room.
    public func itemCount(layer: String, in spaceID: String) -> Int {
        spaces.first { $0.id == spaceID }?.items.filter { $0.layerID == layer }.count ?? 0
    }

    /// Moves items from one room to another, with the items inside moved frames and groups.
    /// Locked items and items on locked layers stay. An item keeps its layer when the target has a layer
    /// with the same ID, otherwise it goes to the first layer of the target.
    /// Returns the number of moved items. Moving within one room moves nothing.
    @discardableResult
    public mutating func moveItems(_ ids: Set<ItemID>, from source: String, to target: String) throws -> Int {
        let from = try spaceIndex(source)
        let to = try spaceIndex(target)
        guard from != to else { return 0 }
        let origin = spaces[from]
        let lockedLayers = Set(origin.layers.filter(\.locked).map(\.id))
        func movable(_ item: Item) -> Bool { !item.locked && !lockedLayers.contains(item.layerID) }

        var moving: [ItemID: Item] = [:]
        for item in origin.items where ids.contains(item.id) && movable(item) { moving[item.id] = item }
        for container in Array(moving.values) where container.isContainer {
            for child in children(of: container, in: origin.items) where movable(child) { moving[child.id] = child }
        }
        guard !moving.isEmpty else { return 0 }

        let arriving = origin.items.filter { moving[$0.id] != nil }
        let existing = Set(spaces[to].items.map(\.id))
        if let clash = arriving.first(where: { existing.contains($0.id) }) { throw SpaceError.duplicateItem(clash.id) }

        if spaces[to].layers.isEmpty { spaces[to].layers = [Layer(id: "standard", name: "Standard")] }
        let targetLayers = Set(spaces[to].layers.map(\.id))
        let fallback = spaces[to].layers[0].id
        var moved = arriving
        for index in moved.indices where !targetLayers.contains(moved[index].layerID) {
            moved[index].layerID = fallback
        }
        spaces[from].items.removeAll { moving[$0.id] != nil }
        spaces[to].items.append(contentsOf: moved)
        return moved.count
    }

    // MARK: Helpers

    private func spaceIndex(_ id: String) throws -> Int {
        guard let index = spaces.firstIndex(where: { $0.id == id }) else { throw SpaceError.unknownSpace(id) }
        return index
    }

    private func layerIndex(_ layer: String, in spaceID: String) throws -> (space: Int, layer: Int) {
        let space = try spaceIndex(spaceID)
        guard let index = spaces[space].layers.firstIndex(where: { $0.id == layer }) else {
            throw SpaceError.unknownLayer(layer)
        }
        return (space, index)
    }

    private static func cleanName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpaceError.emptyName }
        return trimmed
    }
}
