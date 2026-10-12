import Foundation
import AI
import BoardModel

/// The applier of proposal groups: it runs the accepted changes on the board of the store, on the main actor.
public struct BoardProposalApplier: ProposalApplier {
    public let store: BoardStore

    public init(store: BoardStore) {
        self.store = store
    }

    public func apply(_ changes: [ProposedChange]) async -> [ApplyOutcome] {
        await MainActor.run { ProposalBoard.apply(changes, to: store) }
    }
}
