import Foundation

/// The state of one entry of a proposal group.
public enum ProposalState: Equatable, Sendable {
    /// Waiting for the decision of the user.
    case open
    /// Unchosen, or the group was discarded.
    case rejected
    /// Its items are gone from the document. It is grey and cannot be chosen.
    case stale
    /// Applied to the document.
    case applied
    /// Not applied; the reason comes from the applier.
    case failed(String)
}

/// The state of a whole group.
public enum ProposalGroupState: Equatable, Sendable {
    case open
    /// The user accepted the group. Some entries may still have failed.
    case accepted
    case discarded
}

/// The result of one change in the applier.
public enum ApplyOutcome: Equatable, Sendable {
    case applied
    case failed(String)
}

/// Applies accepted changes to the document. The app implements it with its commands.
/// One call is one undo step: the app puts all changes of the call into one batch.
/// It returns one outcome per change, in the same order. A failed change does not stop the others.
public protocol ProposalApplier: Sendable {
    func apply(_ changes: [ProposedChange]) async -> [ApplyOutcome]
}

/// One proposal of the assistant with its choice and its state.
public struct ProposalEntry: Equatable, Sendable, Identifiable {
    /// The ID of the tool call that made the proposal.
    public let id: String
    public let change: ProposedChange
    /// Whether the user keeps this entry for the next accept. A stale entry is never chosen.
    public internal(set) var isChosen: Bool
    public internal(set) var state: ProposalState

    init(id: String, change: ProposedChange) {
        self.id = id
        self.change = change
        self.isChosen = true
        self.state = .open
    }
}

/// All proposals of one answer as one group. Accepting the group is one undo step.
public struct ProposalGroup: Equatable, Sendable, Identifiable {
    public let id: String
    public private(set) var entries: [ProposalEntry]
    public private(set) var state: ProposalGroupState

    /// A group of the given proposals, all chosen and open.
    public static func make(id: String, proposals: [(String, ProposedChange)]) -> ProposalGroup {
        ProposalGroup(
            id: id,
            entries: proposals.map { ProposalEntry(id: $0.0, change: $0.1) },
            state: .open
        )
    }

    private init(id: String, entries: [ProposalEntry], state: ProposalGroupState) {
        self.id = id
        self.entries = entries
        self.state = state
    }

    /// The number of entries that are chosen now.
    public var chosenCount: Int {
        entries.filter(\.isChosen).count
    }

    /// Chooses or unchooses one open entry. Nothing changes after the group is accepted or discarded.
    public mutating func setChosen(_ entryID: String, _ chosen: Bool) {
        guard state == .open, let index = entries.firstIndex(where: { $0.id == entryID }),
              entries[index].state == .open else {
            return
        }
        entries[index].isChosen = chosen
    }

    /// Marks the open entries whose items are gone from the document as stale. They are not chosen any more.
    public mutating func markStale(against document: DocumentSnapshot) {
        for index in entries.indices where entries[index].state == .open {
            guard !Self.isCurrent(entries[index].change, in: document) else { continue }
            entries[index].state = .stale
            entries[index].isChosen = false
        }
    }

    /// Discards the group. Nothing is applied, and every open entry is rejected.
    public mutating func discard() {
        guard state == .open else { return }
        state = .discarded
        rejectOpenEntries()
    }

    /// Applies the chosen entries that are still current, in one call to the applier.
    /// Open entries that were not chosen become rejected. With nothing chosen the group stays open and nothing is applied.
    public func accepting(current document: DocumentSnapshot, applier: any ProposalApplier) async -> ProposalGroup {
        guard state == .open else { return self }
        var next = self
        next.markStale(against: document)
        let chosen = next.entries.indices.filter { next.entries[$0].state == .open && next.entries[$0].isChosen }
        guard !chosen.isEmpty else { return next }

        let outcomes = await applier.apply(chosen.map { next.entries[$0].change })
        for (position, index) in chosen.enumerated() {
            let outcome = position < outcomes.count ? outcomes[position] : .failed("no result from the change")
            switch outcome {
            case .applied:
                next.entries[index].state = .applied
            case let .failed(reason):
                next.entries[index].state = .failed(reason)
            }
        }
        next.rejectOpenEntries()
        next.state = .accepted
        return next
    }

    // MARK: private

    private mutating func rejectOpenEntries() {
        for index in entries.indices where entries[index].state == .open {
            entries[index].state = .rejected
            entries[index].isChosen = false
        }
    }

    /// A change is current when every item it names is in the document; token names check the token IDs.
    static func isCurrent(_ change: ProposedChange, in document: DocumentSnapshot) -> Bool {
        if case let .tokenNames(names) = change {
            return names.allSatisfy { document.tokenIDs.contains($0.id) }
        }
        return change.referencedItems.allSatisfy { document.pieceIDs.contains($0) }
    }
}
