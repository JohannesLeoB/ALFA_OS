import Foundation
import Tokens

/// Unify for colour tokens: colours whose difference (ΔE, CIE76, see `ColorMath.deltaE`) is below the threshold
/// become one token. The first colour in the set order is the anchor, so its value stays and the others are removed.
public enum ColorUnify {
    /// Clusters of colour tokens in one set. Only a cluster with two or more tokens is returned.
    public static func clusters(in set: TokenSet, threshold: Double = 6) -> [UnifyCluster] {
        var groups: [(anchor: Token, lab: Lab, members: [Token])] = []
        for token in set.tokens {
            guard case .color(let color) = token.value else { continue }
            let lab = ColorMath.lab(color)
            if let index = groups.firstIndex(where: { ColorMath.deltaE($0.lab, lab) < threshold }) {
                groups[index].members.append(token)
            } else {
                groups.append((anchor: token, lab: lab, members: [token]))
            }
        }
        return groups.compactMap { group -> UnifyCluster? in
            guard group.members.count >= 2 else { return nil }
            return UnifyCluster(
                set: set.name,
                anchor: group.anchor.path,
                value: group.anchor.value,
                merged: group.members.dropFirst().map(\.path),
                raw: group.members.map(\.value))
        }
    }
}
