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
