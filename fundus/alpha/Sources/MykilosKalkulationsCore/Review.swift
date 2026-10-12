import Foundation

public enum ReviewActionKind: String, Codable, CaseIterable {
    case releaseAsActiveAnchor
    case createCorrectedPriceAnchor
    case markSuperseded
    case markAlternativePriceAtom
    case markAggregateOnly
    case addUserNote
    case airtableOfferImported = "airtable_offer_imported"
}

public struct ReviewAction: Codable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let candidateID: String
    public let kind: ReviewActionKind
    public let note: String
    public let correctedPrice: Decimal?
    public let supersededBy: String?

    public init(id: UUID = UUID(), createdAt: Date = Date(), candidateID: String, kind: ReviewActionKind, note: String, correctedPrice: Decimal? = nil, supersededBy: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.candidateID = candidateID
        self.kind = kind
        self.note = note
        self.correctedPrice = correctedPrice
        self.supersededBy = supersededBy
    }
}

public enum CarryforwardRule {
    public static let forbiddenContexts = ["übertrag", "uebertrag", "nettobetrag", "gesamtbetrag", "mehrwertsteuer", "mwst", "bruttobetrag", "endbetrag", "zwischensumme", "summe"]

    public static func isForbiddenContext(_ text: String) -> Bool {
        let lower = text.lowercased()
        return forbiddenContexts.contains { lower.contains($0) }
    }

    public static func allowsRelease(status: String, text: String) -> Bool {
        if status.hasPrefix("release_candidate_after_carryforward_rule") { return true }
        if isForbiddenContext(text) { return false }
        return true
    }
}

public struct BrainValidator {
    public init() {}

    public func validate(summary: BrainSummary, activeAnchors: [CandidateReleaseDecision]) -> [String] {
        var failures: [String] = []
        if summary.sourceDocuments != 146 { failures.append("PDF files erwartet 146, ist \(summary.sourceDocuments).") }
        if summary.sourcePages != 481 { failures.append("Extracted pages erwartet 481, ist \(summary.sourcePages).") }
        if summary.offerPositionBlocks != 815 { failures.append("Position candidates erwartet 815, ist \(summary.offerPositionBlocks).") }
        if summary.componentPriceAtoms != 199 { failures.append("ComponentPriceAtoms erwartet 199, ist \(summary.componentPriceAtoms).") }
        if summary.moneyObservations != 3384 { failures.append("MoneyObservations erwartet 3384, ist \(summary.moneyObservations).") }
        if summary.candidateReleaseDecisions != 815 { failures.append("CandidateReleaseDecisions erwartet 815, ist \(summary.candidateReleaseDecisions).") }
        if summary.releaseReadyActiveAnchors != 201 { failures.append("Active price anchors erwartet 201, ist \(summary.releaseReadyActiveAnchors).") }
        if summary.manualReviewItems != 339 { failures.append("Review queue erwartet 339, ist \(summary.manualReviewItems).") }
        if summary.supersededItems != 275 { failures.append("Superseded candidates erwartet 275, ist \(summary.supersededItems).") }
        if activeAnchors.contains(where: { $0.isSuperseded || (!$0.isReleaseReady && $0.sourceKind != .ruleBasedAnchor) }) {
            failures.append("Estimator anchors enthalten superseded oder nicht freigegebene Records.")
        }
        let unsafe = activeAnchors.filter {
            let status = $0.carryforwardRuleStatus.lowercased()
            let releaseApproved = $0.isReleaseReady || $0.sourceKind == .ruleBasedAnchor || $0.ruleNotes == "component_price_atom"
            let safe = releaseApproved || status.hasPrefix("double_ep_gp") || status.contains("double_e_g_price")
            return CarryforwardRule.isForbiddenContext($0.evidenceQuote) && !safe
        }
        if !unsafe.isEmpty {
            failures.append("Carryforward-Regel verletzt: \(unsafe.map(\.candidateID).prefix(5).joined(separator: ", ")).")
        }
        return failures
    }
}
