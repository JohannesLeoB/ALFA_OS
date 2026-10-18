import Foundation
import MykilosKalkulationsCore
import AlfaKit

public struct AirtableAnchorProvider: PriceAnchorProviding {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.estimation_model")
    public static let table  = "Preisanker"

    private let fetcher: AirtableFetching
    private let fallback: PriceAnchorProviding
    private let cache: AnkerSpeicher
    private let scopeCatalog: ScopeSignatureCatalog

    public init(
        fetcher: AirtableFetching = AirtableClient(),
        fallback: PriceAnchorProviding = BrainSeedProvider(),
        cache: AnkerSpeicher = AnkerSpeicher(),
        scopeCatalog: ScopeSignatureCatalog? = nil
    ) {
        self.fetcher = fetcher
        self.fallback = fallback
        self.cache = cache
        self.scopeCatalog = scopeCatalog ?? ScopeSignatureCatalog.load()
    }

    @discardableResult
    public func vorwaermen() async -> Int {
        guard let records = try? await fetcher.fetchRecords(baseID: Self.baseID, table: Self.table) else {
            return 0
        }
        let anchors = records.compactMap { record -> CandidateReleaseDecision? in
            let row = record.mapValues(Self.rohwert)
            return BrainSeedProvider.anchor(from: row)
        }
        guard anchors.isEmpty == false else { return 0 }
        cache.speichere(anchors)
        return anchors.count
    }

    static func rohwert(_ value: AirtableFieldValue) -> String {
        value.anyStringValue ?? value.firstArrayValue ?? ""
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        let gecacht = cache.load()
        guard gecacht.isEmpty == false else {
            return try fallback.activeAnchors()
        }
        return scopeCatalog.enrich(gecacht)
    }
}

public final class AnkerSpeicher: @unchecked Sendable {
    private let lock = NSLock()
    private var anker: [CandidateReleaseDecision] = []

    public init() {}

    public func speichere(_ neu: [CandidateReleaseDecision]) {
        lock.lock(); defer { lock.unlock() }
        anker = neu
    }

    public func load() -> [CandidateReleaseDecision] {
        lock.lock(); defer { lock.unlock() }
        return anker
    }
}
