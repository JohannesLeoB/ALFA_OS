import Foundation
import ALFAcolorCore

/// Changes to the folders of a board. Each function changes the list it is given, or throws and changes nothing.
/// The app applies them with `BoardStore.changeBoard`, which makes each one an undo step.
public enum FolderEdit {
    public enum Failure: Error, Equatable, Sendable {
        /// The name is empty after trimming white space.
        case emptyName
        /// A folder with this ID exists already.
        case duplicateID(String)
        case unknownFolder(String)
        /// An item that is not in the board. Only the room and the ID are checked.
        case unknownItem(ItemRef)
        /// Items are added or removed by hand only in a fixed folder.
        case notFixed(String)
    }

    /// Adds a folder at the end of the list.
    public static func add(_ folder: Folder, to folders: inout [Folder]) throws {
        guard !folder.name.trimmed.isEmpty else { throw Failure.emptyName }
        guard !folders.contains(where: { $0.id == folder.id }) else { throw Failure.duplicateID(folder.id) }
        var folder = folder
        folder.name = folder.name.trimmed
        folders.append(folder)
    }

    /// Renames a folder. The ID and the rule stay.
    public static func rename(_ id: String, to name: String, in folders: inout [Folder]) throws {
        guard !name.trimmed.isEmpty else { throw Failure.emptyName }
        let index = try position(of: id, in: folders)
        folders[index].name = name.trimmed
    }

    /// Removes a folder. The items stay in their rooms.
    public static func delete(_ id: String, from folders: inout [Folder]) throws {
        folders.remove(at: try position(of: id, in: folders))
    }

    /// Adds items to the end of a fixed folder. An item that is in the folder already is not added again.
    /// Every item must be in `board`.
    public static func addItems(_ refs: [ItemRef], to id: String, in folders: inout [Folder], board: Board) throws {
        let index = try position(of: id, in: folders)
        guard case .fixed(var list) = folders[index].rule else { throw Failure.notFixed(id) }
        let known = Set(board.spaces.flatMap { space in space.items.map { ItemRef(spaceID: space.id, itemID: $0.id) } })
        for ref in refs {
            guard known.contains(ref) else { throw Failure.unknownItem(ref) }
            if !list.contains(ref) { list.append(ref) }
        }
        folders[index].rule = .fixed(list)
    }

    /// Removes items from a fixed folder. Items that are not in it are ignored.
    public static func removeItems(_ refs: [ItemRef], from id: String, in folders: inout [Folder]) throws {
        let index = try position(of: id, in: folders)
        guard case .fixed(let list) = folders[index].rule else { throw Failure.notFixed(id) }
        let drop = Set(refs)
        folders[index].rule = .fixed(list.filter { !drop.contains($0) })
    }

    private static func position(of id: String, in folders: [Folder]) throws -> Int {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { throw Failure.unknownFolder(id) }
        return index
    }
}

extension LibraryIndex {
    /// The items of a folder, in the order the folder shows them. A fixed folder skips items that are no longer
    /// in the board and keeps the order of its list. A smart folder shows what its filter finds.
    public func items(in folder: Folder) -> [ItemRef] {
        switch folder.rule {
        case .smart(let filter):
            return search(filter)
        case .fixed(let list):
            let present = Set(records.map(\.ref))
            return list.filter { present.contains($0) }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
