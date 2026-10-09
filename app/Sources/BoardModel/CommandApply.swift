import Foundation
import ALFAcolorCore

extension Command {
    /// Applies the command to one space of a board and returns the edit that undoes it.
    /// Returns nil when nothing changed. On an error the board is unchanged.
    ///
    /// `selection` is the selection before the command. The edit holds the selection after it.
    public func apply(to board: inout Board, spaceID: String, selection: Set<ItemID> = []) throws -> Edit? {
        guard let spaceIndex = board.spaces.firstIndex(where: { $0.id == spaceID }) else { throw CommandError.unknownSpace(spaceID) }
        switch self {
        case .switchSpace(let target):
            guard board.spaces.contains(where: { $0.id == target }) else { throw CommandError.unknownSpace(target) }
            return nil
        case .batch(let commands, _):
            var trial = board
            var current = selection
            var steps: [ItemDelta] = []
            for command in commands {
                if case .switchSpace = command { throw CommandError.notBatchable }
                if let edit = try command.apply(to: &trial, spaceID: spaceID, selection: current) {
                    steps += edit.steps
                    current = edit.selectionAfter
                }
            }
            guard !steps.isEmpty else { return nil }
            board = trial
            return Edit(spaceID: spaceID, steps: steps, selectionBefore: selection, selectionAfter: current)
        default:
            let scope = StepScope(board: board, spaceIndex: spaceIndex)
            guard let result = try scope.run(self, selection: selection) else { return nil }
            let space = board.spaces[spaceIndex]
            let delta = ItemDelta(before: ItemDelta.entries(of: result.touched, in: space.items),
                                  after: ItemDelta.entries(of: result.touched, in: result.items))
            guard !delta.isEmpty else { return nil }
            board.spaces[spaceIndex].items = result.items
            let existing = Set(result.items.map(\.id))
            return Edit(spaceID: spaceID, steps: [delta], selectionBefore: selection, selectionAfter: result.selection.intersection(existing))
        }
    }
}
