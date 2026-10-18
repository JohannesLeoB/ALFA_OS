import Foundation
import AlfaCalculation

public struct BaselineAnchorProvider: PriceAnchorProviding {
    public init() {}

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        BaselineAnchors.all()
    }
}
