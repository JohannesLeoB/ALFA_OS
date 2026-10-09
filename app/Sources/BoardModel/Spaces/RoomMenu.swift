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
    /// Opens the room with this ID and name. `active` marks the open room.
    case room(id: String, name: String, active: Bool)
}

/// The entries of the room menu, in display order: the three room actions, then one entry per room.
public enum RoomMenu {
    public static func items(spaces: [Space], active: String?) -> [RoomMenuItem] {
        let hasActive = spaces.contains { $0.id == active }
        let rooms = spaces.map { RoomMenuItem.room(id: $0.id, name: $0.name, active: $0.id == active) }
        return [.add, .rename(enabled: hasActive), .close(enabled: hasActive && spaces.count > 1)] + rooms
    }
}
