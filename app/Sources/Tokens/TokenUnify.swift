import Foundation

/// Unify: near values become one token. The anchor keeps its path and takes the target value,
/// and the other members are removed. A cluster is shown before it is applied, so each change is visible.
public struct UnifyCluster: Equatable, Sendable {
    /// Name of the token set that holds the members.
    public var set: String
    /// Path of the token that stays.
    public var anchor: [String]
    /// The value the anchor takes.
    public var value: TokenValue
    /// Paths of the tokens that are removed.
    public var merged: [[String]]
    /// The values of all members before the change, in the order of the set.
    public var raw: [TokenValue]

    public init(set: String, anchor: [String], value: TokenValue, merged: [[String]], raw: [TokenValue]) {
        self.set = set; self.anchor = anchor; self.value = value; self.merged = merged; self.raw = raw
    }
}

public enum TokenUnify {
    /// Pixel dimensions grouped by their first path part (for example "space") and pulled to the nearest step.
    /// With step 4, the values 15, 16 and 17 all go to 16. Only a target with two or more tokens makes a cluster.
    /// The anchor is the token that already has the target value, else the first token of the group.
    public static func dimensionClusters(in set: TokenSet, step: Double = 4) -> [UnifyCluster] {
        guard step > 0 else { return [] }
        struct Key: Hashable { var group: String; var target: Double }
        var order: [Key] = []
        var members: [Key: [(token: Token, x: Double)]] = [:]
        for token in set.tokens {
            guard case .dimension(let x, let unit) = token.value, unit == "px", let group = token.path.first else { continue }
            let key = Key(group: group, target: (x / step).rounded() * step)
            if members[key] == nil { order.append(key) }
            members[key, default: []].append((token, x))
        }
        return order.compactMap { key -> UnifyCluster? in
            guard let group = members[key], group.count >= 2 else { return nil }
            let anchor = group.first { $0.x == key.target } ?? group[0]
            return UnifyCluster(
                set: set.name,
                anchor: anchor.token.path,
                value: .dimension(key.target, unit: "px"),
                merged: group.map(\.token.path).filter { $0 != anchor.token.path },
                raw: group.map(\.token.value))
        }
    }

    /// Applies clusters to the token sets: the members are removed, and each anchor takes its target value.
    /// A cluster for a set or a token that is not there is skipped. The caller keeps the old sets for undo.
    public static func apply(_ clusters: [UnifyCluster], to sets: inout [TokenSet]) {
        for cluster in clusters {
            guard let index = sets.firstIndex(where: { $0.name == cluster.set }) else { continue }
            sets[index].tokens.removeAll { cluster.merged.contains($0.path) }
            if let anchor = sets[index].tokens.firstIndex(where: { $0.path == cluster.anchor }) {
                sets[index].tokens[anchor].value = cluster.value
            }
        }
    }
}
