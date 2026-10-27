import Foundation
import Synchronization

public final class AnchorStore: PriceAnchorPort {
    private let source: any AnchorRowsPort
    private let fallback: any PriceAnchorPort
    private let scopeDensity: ScopeDensityEngine
    private let cache = Mutex<[CandidateReleaseDecision]>([])

    public init(source: any AnchorRowsPort, scopeSignaturesURL: URL? = nil, fallback: any PriceAnchorPort) {
        self.source = source
        self.fallback = fallback
        self.scopeDensity = CorpusAnchorStore.loadScopeDensity(from: scopeSignaturesURL)
    }

    @discardableResult
    public func warmUp() async -> Int {
        guard let rows = try? await source.fetchAnchorRows() else { return 0 }
        let anchors = rows.compactMap(CorpusAnchorStore.anchor(from:))
        guard anchors.isEmpty == false else { return 0 }
        cache.withLock { $0 = anchors }
        return anchors.count
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        let cached = cache.withLock { $0 }
        guard cached.isEmpty == false else {
            return try fallback.activeAnchors()
        }
        return scopeDensity.enrich(cached)
    }
}
