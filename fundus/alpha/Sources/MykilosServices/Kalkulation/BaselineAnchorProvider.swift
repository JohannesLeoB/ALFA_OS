import Foundation
import MykilosKalkulationsCore

public struct BaselineAnchorProvider: PriceAnchorProviding {
    public init() {}

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        BaselineAnchors.all()
    }
}
