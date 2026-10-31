import Core
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

public struct CompositeAnchorStore: PriceAnchorPort {
    private let primary: any PriceAnchorPort
    private let learned: any PriceAnchorPort
    private let pdfLearned: (any PriceAnchorPort)?

    public init(primary: any PriceAnchorPort, learned: any PriceAnchorPort, pdfLearned: (any PriceAnchorPort)? = nil) {
        self.primary = primary
        self.learned = learned
        self.pdfLearned = pdfLearned
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        let base = try primary.activeAnchors()
        return base + orEmpty(learned) + (pdfLearned.map(orEmpty) ?? [])
    }

    private func orEmpty(_ provider: any PriceAnchorPort) -> [CandidateReleaseDecision] {
        (try? provider.activeAnchors()) ?? []
    }
}

struct CorpusAnchorStore: PriceAnchorPort {
    private let csvURL: URL
    private let fallback: any PriceAnchorPort
    private let scopeDensity: ScopeDensityEngine

    init(csvURL: URL, scopeSignaturesURL: URL? = nil, fallback: any PriceAnchorPort = SeedAnchors()) {
        self.csvURL = csvURL
        self.fallback = fallback
        self.scopeDensity = Self.loadScopeDensity(from: scopeSignaturesURL)
    }

    func activeAnchors() throws -> [CandidateReleaseDecision] {
        guard let raw = try? String(contentsOf: csvURL, encoding: .utf8) else {
            return try fallback.activeAnchors()
        }
        let table = try CSVTable(data: raw, lenient: true)
        let anchors = table.rows.compactMap(Self.anchor(from:))
        guard anchors.isEmpty == false else { return try fallback.activeAnchors() }
        return scopeDensity.enrich(anchors)
    }

    static func loadScopeDensity(from url: URL?) -> ScopeDensityEngine {
        guard let url, let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return ScopeDensityEngine(densityByCandidate: [:])
        }
        return ScopeDensityEngine(csv: raw)
    }

    static func anchor(from row: [String: String]) -> CandidateReleaseDecision? {
        let id = row.string("candidate_id")
        guard id.isEmpty == false else { return nil }
        let price = row.decimal("price_net")
        guard price > 0 else { return nil }
        if row.string("superseded_by_candidate").isEmpty == false { return nil }

        let materials = row.string("materials")
        let dimension = row.string("dimension_raw")
        let original = row.string("original_text")
        let classRaw = row.string("component_class")
        let componentClass = ComponentClass(rawValue: classRaw)

        let label = [classRaw, materials, dimension]
            .filter { $0.isEmpty == false }.joined(separator: " ")
        let status = row.string("status").isEmpty ? "release_candidate" : row.string("status")

        return CandidateReleaseDecision(
            candidateID: id,
            sourceFile: row.string("document"),
            page: row.int("page_start"),
            supplier: row.string("supplier"),
            project: row.string("project"),
            component: [materials, dimension].filter { !$0.isEmpty }.joined(separator: " "),
            trade: row.string("doc_type"),
            priceNetGuess: price,
            confidence: row.double("confidence"),
            duplicateCount: 0,
            currentStatus: status,
            proposedStatus: status,
            supersededBy: nil,
            decisionScore: row.double("confidence"),
            decisionReason: row.string("risk_flags"),
            helpNeeded: "",
            title: label.isEmpty ? id : label,
            evidenceQuote: original.isEmpty ? label : original,
            carryforwardRuleStatus: "",
            ruleSafePriceNet: nil,
            ruleNotes: row.string("scope_json"),
            componentClass: componentClass,
            sourceKind: .pdfOffer
        )
    }
}

public struct LearnedAnchorStore: PriceAnchorPort {
    private let store: LearningStore
    private let referenceYear: Int

    public init(store: LearningStore, referenceYear: Int? = nil) {
        self.store = store
        self.referenceYear = referenceYear ?? Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        try store.confirmedOffers().compactMap { entry in
            guard entry.netEur > 0 else { return nil }
            guard let reason = entry.offerStatus.learningReason(kind: entry.offerKind) else { return nil }

            let offerYear = AnchorInflation.year(from: entry.offerDate)
            let inflation = AnchorInflation.factor(offerYear: offerYear, referenceYear: referenceYear)
            let presentValue = entry.netEur * inflation
            let confidence = LearningStore.baseConfidence(for: reason)
                * AnchorInflation.confidenceFactor(offerYear: offerYear, referenceYear: referenceYear)

            let quote = [entry.partner, offerYear.map(String.init) ?? "-", presentValue.description].joined(separator: " · ")

            return CandidateReleaseDecision(
                candidateID: "LEARNED-\(entry.sourceRecordID)",
                sourceFile: "supplier_offers",
                page: 0,
                supplier: entry.partner,
                project: "",
                component: entry.partner,
                trade: reason.rawValue,
                priceNetGuess: presentValue,
                confidence: confidence,
                duplicateCount: 0,
                currentStatus: "release_candidate",
                proposedStatus: "release_candidate",
                supersededBy: nil,
                decisionScore: confidence,
                decisionReason: "learned_incoming_offer",
                helpNeeded: "",
                title: entry.partner,
                evidenceQuote: quote,
                carryforwardRuleStatus: "",
                ruleSafePriceNet: nil,
                ruleNotes: "",
                componentClass: .aggregateKitchen,
                sourceKind: .pdfOffer
            )
        }
    }
}

public struct PdfAnchorStore: PriceAnchorPort {
    private let store: LearningStore

    public init(store: LearningStore) {
        self.store = store
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        try store.confirmedPdfPositions().compactMap { position in
            guard position.netPrice > 0 else { return nil }

            let quote = [position.title, position.sourceFile, String(position.pageNumber)].joined(separator: " · ")
            return CandidateReleaseDecision(
                candidateID: position.id,
                sourceFile: position.sourceFile,
                page: position.pageNumber,
                supplier: "calc.pdf.supplier",
                project: "",
                component: position.title,
                trade: "pdf_extraction",
                priceNetGuess: position.netPrice,
                confidence: min(1, max(0, position.confidence)) * 0.85,
                duplicateCount: 0,
                currentStatus: "release_pdf_confirmed",
                proposedStatus: "release_pdf_confirmed",
                supersededBy: nil,
                decisionScore: position.confidence * 0.85,
                decisionReason: "pdf_extracted_locally",
                helpNeeded: "",
                title: position.title,
                evidenceQuote: quote,
                carryforwardRuleStatus: "",
                ruleSafePriceNet: nil,
                ruleNotes: "pdf_extraction_local",
                componentClass: position.componentClass,
                sourceKind: .pdfOffer)
        }
    }
}
