import Foundation

public struct CandidateReleaseDecision: Equatable, Identifiable, Sendable {
    public var id: String { candidateID }
    let candidateID: String
    let sourceFile: String
    let page: Int
    let supplier: String
    let project: String
    let component: String
    let trade: String
    let priceNetGuess: Decimal
    let confidence: Double
    let duplicateCount: Int
    let currentStatus: String
    let proposedStatus: String
    let supersededBy: String?
    let decisionScore: Double
    let decisionReason: String
    let helpNeeded: String
    let title: String
    let evidenceQuote: String
    let carryforwardRuleStatus: String
    let ruleSafePriceNet: Decimal?
    let ruleNotes: String
    let componentClass: ComponentClass
    let sourceKind: AnchorSourceKind
    let equipmentDensity: EquipmentDensity

    var isReleaseReady: Bool { proposedStatus.hasPrefix("release_") }
    var isSuperseded: Bool { proposedStatus.hasPrefix("superseded_") || supersededBy?.isEmpty == false }

    var materialsText: String { [title, evidenceQuote].joined(separator: " ") }

    var lengthM: Double? {
        let pattern = #"([0-9]+(?:[,.][0-9]+)?)\s*(?:lfm|meter|m)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let text = [title, evidenceQuote].joined(separator: " ")
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, range: nsRange),
              let range = Range(result.range(at: 1), in: text) else { return nil }
        return NumberParser.double(String(text[range]))
    }

    init(candidateID: String, sourceFile: String, page: Int, supplier: String, project: String, component: String, trade: String, priceNetGuess: Decimal, confidence: Double, duplicateCount: Int, currentStatus: String, proposedStatus: String, supersededBy: String?, decisionScore: Double, decisionReason: String, helpNeeded: String, title: String, evidenceQuote: String, carryforwardRuleStatus: String, ruleSafePriceNet: Decimal?, ruleNotes: String, componentClass: ComponentClass? = nil, sourceKind: AnchorSourceKind = .pdfOffer, equipmentDensity: EquipmentDensity = .unknown) {
        self.candidateID = candidateID
        self.sourceFile = sourceFile
        self.page = page
        self.supplier = supplier
        self.project = project
        self.component = component
        self.trade = trade
        self.priceNetGuess = priceNetGuess
        self.confidence = confidence
        self.duplicateCount = duplicateCount
        self.currentStatus = currentStatus
        self.proposedStatus = proposedStatus
        self.supersededBy = supersededBy
        self.decisionScore = decisionScore
        self.decisionReason = decisionReason
        self.helpNeeded = helpNeeded
        self.title = title
        self.evidenceQuote = evidenceQuote
        self.carryforwardRuleStatus = carryforwardRuleStatus
        self.ruleSafePriceNet = ruleSafePriceNet
        self.ruleNotes = ruleNotes
        self.componentClass = componentClass ?? CandidateReleaseDecision.classify(component: component, trade: trade, title: title, evidenceQuote: evidenceQuote, proposedStatus: proposedStatus)
        self.sourceKind = sourceKind
        self.equipmentDensity = equipmentDensity
    }

    func withEquipmentDensity(_ density: EquipmentDensity) -> CandidateReleaseDecision {
        CandidateReleaseDecision(
            candidateID: candidateID, sourceFile: sourceFile, page: page, supplier: supplier,
            project: project, component: component, trade: trade, priceNetGuess: priceNetGuess,
            confidence: confidence, duplicateCount: duplicateCount, currentStatus: currentStatus,
            proposedStatus: proposedStatus, supersededBy: supersededBy, decisionScore: decisionScore,
            decisionReason: decisionReason, helpNeeded: helpNeeded, title: title,
            evidenceQuote: evidenceQuote, carryforwardRuleStatus: carryforwardRuleStatus,
            ruleSafePriceNet: ruleSafePriceNet, ruleNotes: ruleNotes, componentClass: componentClass,
            sourceKind: sourceKind, equipmentDensity: density
        )
    }

    static func classify(component: String, trade: String, title: String, evidenceQuote: String, proposedStatus: String) -> ComponentClass {
        let lower = [component, trade, title, evidenceQuote, proposedStatus].joined(separator: " ").lowercased()
        if lower.contains("alternative") || lower.contains("mehrpreis") || lower.contains("eventual") { return .alternative }
        if lower.contains("gerät") || lower.contains("geraet") { return .applianceHandling }
        if lower.contains("montage") || lower.contains("lieferung") || lower.contains("transport") || lower.contains("handling") { return .logistics }
        if lower.contains("arbeitsplatte") || lower.contains("steinmetz") || lower.contains("dekton") || lower.contains("quarzit") { return .worktopSurface }
        if lower.contains("pantry") { return .unknownReview }
        if lower.contains("hochschrank") { return .tallCabinetBlock }
        if lower.contains("insel") || lower.contains("block") { return .island }
        if lower.contains("küchenzeile") || lower.contains("kuechenzeile") || lower.contains("zeile") || lower.contains("unterschrank") { return .kitchenRun }
        if lower.contains("gesamt") || lower.contains("küche") || lower.contains("kueche") { return .aggregateKitchen }
        return .unknownReview
    }
}

enum AnchorSourceKind: String, Equatable, Sendable {
    case pdfOffer = "pdf_offer"
    case ruleBasedAnchor = "rule_based_anchor"
}
