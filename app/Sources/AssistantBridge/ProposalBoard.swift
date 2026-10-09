import Foundation
import AI
import BoardModel

/// Applies accepted assistant proposals to the board of the app with the app's commands.
@MainActor
public enum ProposalBoard {
    /// Applies the changes in order and returns one outcome per change, in the same order.
    /// A change that fails does not stop the others.
    public static func apply(_ changes: [ProposedChange], to store: BoardStore) -> [ApplyOutcome] {
        changes.map { _ in ApplyOutcome.failed("not translated yet") }
    }
}
