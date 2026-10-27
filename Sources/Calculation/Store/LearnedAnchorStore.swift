import Foundation

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
