import Foundation
import ALFAcolorCore
import Tokens

/// Commands of the token workshop. Each one is one undo step, named by its key in the string catalog.
extension BoardStore {
    /// Applies unify clusters, for example from `TokenUnify.dimensionClusters` or `ColorUnify.clusters`.
    /// Undo gives back the sets as they were, so it also undoes the summary. Returns false when nothing changed.
    @discardableResult
    public func unifyTokens(_ clusters: [UnifyCluster]) throws -> Bool {
        try changeTokenSets(nameKey: "undo.workshop.unify") { TokenUnify.apply(clusters, to: &$0) }
    }

    /// Accepts one name suggestion: the token gets the proposed path. One undo step.
    /// Throws when the path is taken, and then nothing changes.
    @discardableResult
    public func acceptName(_ suggestion: WorkshopNames.Suggestion) throws -> Bool {
        try changeTokenSets(nameKey: "undo.workshop.name") { try WorkshopNames.accept(suggestion, in: &$0) }
    }
}
