import Foundation
import AlfaKit
import MykilosKalkulationsCore

public struct BrainSeedProvider: PriceAnchorProviding {
    private let csvURL: URL
    private let fallback: PriceAnchorProviding
    private let scopeCatalog: ScopeSignatureCatalog

    public init(csvURL: URL? = nil,
                fallback: PriceAnchorProviding = BaselineAnchorProvider(),
                scopeCatalog: ScopeSignatureCatalog? = nil) {
        self.csvURL = csvURL ?? BrainSeedProvider.defaultURL
        self.fallback = fallback

        self.scopeCatalog = scopeCatalog ?? ScopeSignatureCatalog.load()
    }

    public static var defaultURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("\(AppKennung.name)/Kalkulationslabor/Brain/active_price_anchors.csv")
    }

    public var isCorpusAvailable: Bool {
        FileManager.default.fileExists(atPath: csvURL.path)
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        guard let raw = try? String(contentsOf: csvURL, encoding: .utf8) else {
            return try fallback.activeAnchors()
        }
        let table = try CSVTable(data: raw, lenient: true)
        let anchors = table.rows.compactMap(Self.anchor(from:))

        guard anchors.isEmpty == false else { return try fallback.activeAnchors() }

        return scopeCatalog.enrich(anchors)
    }

    static func anchor(from row: [String: String]) -> CandidateReleaseDecision? {
        let id = row.string("candidate_id")
        guard id.isEmpty == false else { return nil }
        let price = row.decimal("price_net")
        guard price > 0 else { return nil }
        if row.string("superseded_by_candidate").isEmpty == false { return nil }

        let materials   = row.string("materials")
        let dimension   = row.string("dimension_raw")
        let original    = row.string("original_text")
        let classRaw    = row.string("component_class")
        let componentClass = CalculationComponentClass(rawValue: classRaw)

        let label = [componentClass?.displayName ?? classRaw, materials, dimension]
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
            title: label.isEmpty ? "Anker \(id)" : label,
            evidenceQuote: original.isEmpty ? label : original,
            carryforwardRuleStatus: "",
            ruleSafePriceNet: nil,
            ruleNotes: row.string("scope_json"),
            componentClass: componentClass,
            sourceKind: .pdfOffer
        )
    }
}
