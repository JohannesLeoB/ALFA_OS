import BoardModel
import Document
import Foundation
import Tokens

/// One token that a delivery adds, changes or removes, compared with the document.
public struct TokenChange: Equatable, Sendable {
    public enum Kind: String, Sendable, Equatable {
        case added, changed, removed
    }

    public let kind: Kind
    /// The token path with dots, for example `color.akzent`.
    public let id: String
}

public enum TokenDiff {
    /// Compares by token path. A token counts as changed when its value or its description differs.
    /// `old` is the set of the document with the same name, nil when there is none.
    public static func changes(from old: TokenSet?, to new: TokenSet) -> [TokenChange] {
        let before = Dictionary((old?.tokens ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let after = Dictionary(new.tokens.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var changes: [TokenChange] = []
        for (id, token) in after {
            guard let previous = before[id] else {
                changes.append(TokenChange(kind: .added, id: id))
                continue
            }
            if previous.value != token.value || previous.description != token.description {
                changes.append(TokenChange(kind: .changed, id: id))
            }
        }
        for id in before.keys where after[id] == nil {
            changes.append(TokenChange(kind: .removed, id: id))
        }
        return changes.sorted { $0.id.lexicographicallyPrecedes($1.id) }
    }
}

/// Puts a contract into the document as one undo step.
public enum ContractApply {
    /// Each set replaces the set with the same name, or is added. A dark set that the contract does not
    /// have is removed, so no old dark values stay behind. Returns false when nothing changes.
    @MainActor
    public static func apply(_ contract: ContractSets, to store: BoardStore) throws -> Bool {
        try store.changeTokenSets(nameKey: "undo.contract.import") { current in
            for set in contract.sets {
                if let index = current.firstIndex(where: { $0.name == set.name }) {
                    current[index] = set
                } else {
                    current.append(set)
                }
            }
            if contract.dark == nil {
                current.removeAll { $0.name == ContractSets.darkName }
            }
        }
    }
}
