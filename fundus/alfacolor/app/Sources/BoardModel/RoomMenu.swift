import Foundation
import ALFAcolorCore

/// An entry of the room menu. The menu has no keys: every entry is reached with the mouse.
public enum RoomMenuItem: Equatable, Sendable {
    /// Adds a room at the end and opens it.
    case add
    /// Renames the open room. Disabled when there is no open room.
    case rename(enabled: Bool)
    /// Closes the open room. Disabled while it is the only room.
    case close(enabled: Bool)
    /// Moves the open room one place to the left or to the right in the tab order.
    case moveLeft(enabled: Bool)
    case moveRight(enabled: Bool)
    /// Separates the groups of the menu.
    case divider
    /// Opens the room with this ID and name. `active` marks the open room.
    case room(id: String, name: String, active: Bool)
}

/// The entries of the room menu, in display order: the room actions, then one entry per room.
/// The menu keeps working from the seventh room on, when the tab row is replaced by it.
public enum RoomMenu {
    public static func items(spaces: [Space], active: String?) -> [RoomMenuItem] {
        let index = spaces.firstIndex { $0.id == active }
        let hasActive = index != nil
        let rooms = spaces.map { RoomMenuItem.room(id: $0.id, name: $0.name, active: $0.id == active) }
        let actions: [RoomMenuItem] = [
            .add,
            .rename(enabled: hasActive),
            .close(enabled: hasActive && spaces.count > 1),
            .divider,
            .moveLeft(enabled: (index ?? 0) > 0 && hasActive),
            .moveRight(enabled: index.map { $0 < spaces.count - 1 } ?? false),
            .divider,
        ]
        return actions + rooms
    }
}
