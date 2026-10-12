import Foundation
import MykilosKalkulationsCore

public enum OfferAnchorInflation {
    public static let annualRate = 0.04

    public static let maxYears = 6

    public static func year(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let digits = Array(raw)
        for start in 0...(max(0, digits.count - 4)) where start + 4 <= digits.count {
            let window = digits[start..<start + 4]
            guard window.allSatisfy(\.isNumber) else { continue }
            let value = Int(String(window)) ?? 0
            if value >= 1900 && value <= 2100 { return value }
        }
        return nil
    }

    public static func factor(offerYear: Int?, referenceYear: Int) -> Decimal {
        guard let offerYear, offerYear < referenceYear else { return 1 }
        let years = min(referenceYear - offerYear, maxYears)
        let grown = pow(1 + annualRate, Double(years))
        return Decimal(grown)
    }

    public static func confidenceFactor(offerYear: Int?, referenceYear: Int) -> Double {
        guard let offerYear else { return 0.7 }
        let years = max(0, min(referenceYear - offerYear, maxYears))
        return max(0.55, 1 - Double(years) * 0.06)
    }
}

public extension LearningStore {
    internal static func baseConfidence(for reason: EstimateAdjustmentReason) -> Double {
        switch reason {
        case .finalInvoiceReceived: return 0.9
        case .realOfferReceived:    return 0.75
        default:                    return 0.6
        }
    }

    @discardableResult
    func syncAirtableOffers(_ offers: [AirtableOfferEntry]) throws -> AirtableOfferSyncReport {
        let learningDB = try database()
        var imported = 0, skippedDuplicate = 0, skippedNoSignal = 0
        var errors: [String] = []

        for offer in offers {
            guard offer.kind == .eingehend, offer.status.learningReason(kind: offer.kind) != nil else {
                skippedNoSignal += 1
                continue
            }
            do {
                if try learningDB.airtableRecordIDExists(offer.airtableRecordID) {
                    skippedDuplicate += 1
                    continue
                }
                let entry = AirtableOfferSyncEntry(
                    airtableRecordID: offer.airtableRecordID,
                    offerKind: offer.kind,
                    nettoEur: offer.nettoEur,
                    offerStatus: offer.status,
                    partner: offer.partner,
                    docSHA256: nil,
                    reviewActionID: nil,
                    syncStatus: "imported",
                    offerDate: offer.datum
                )
                try learningDB.write { conn in
                    try learningDB.insert(entry, conn)
                    try learningDB.insert(
                        LearningAuditLogEntry(
                            entityID: entry.id,
                            entityTable: "airtable_offer_sync",
                            action: "offer_imported",
                            message: "Eingehendes Angebot \(offer.partner) (netto \(offer.nettoEur)) importiert — Review steht aus."
                        ),
                        conn
                    )
                }
                imported += 1
            } catch {
                errors.append("\(offer.airtableRecordID): \(error)")
            }
        }
        return AirtableOfferSyncReport(
            fetched: offers.count,
            skippedDuplicate: skippedDuplicate,
            skippedNoSignal: skippedNoSignal,
            imported: imported,
            errors: errors
        )
    }

    @discardableResult
    func confirmOfferAnchor(airtableRecordID: String, note: String = "") throws -> ReviewAction {
        let learningDB = try database()
        let action = ReviewAction(
            candidateID: airtableRecordID,
            kind: .releaseAsActiveAnchor,
            note: note
        )
        try learningDB.write { conn in
            try learningDB.insert(action, conn)
            try learningDB.insert(
                LearningAuditLogEntry(
                    entityID: airtableRecordID,
                    entityTable: "airtable_offer_sync",
                    action: "offer_confirmed",
                    message: "Angebot \(airtableRecordID) als Kostenanker freigegeben. \(note)"
                ),
                conn
            )
        }
        return action
    }

    func offerSyncEntries() throws -> [AirtableOfferSyncEntry] {
        try database().airtableOfferSyncEntries()
    }

    func confirmedOfferRecordIDs() throws -> Set<String> {
        let actions = try database().reviewActions()
        return Set(actions.filter { $0.kind == .releaseAsActiveAnchor }.map(\.candidateID))
    }

    func pendingOfferSyncEntries() throws -> [AirtableOfferSyncEntry] {
        let confirmed = try confirmedOfferRecordIDs()
        return try offerSyncEntries().filter { !confirmed.contains($0.airtableRecordID) }
    }

    func confirmedOfferSyncEntries() throws -> [AirtableOfferSyncEntry] {
        let confirmed = try confirmedOfferRecordIDs()
        return try offerSyncEntries().filter { confirmed.contains($0.airtableRecordID) }
    }
}

public struct LearnedAnchorProvider: PriceAnchorProviding {
    private let store: LearningStore
    private let referenceYear: Int

    public init(store: LearningStore, referenceYear: Int? = nil) {
        self.store = store
        self.referenceYear = referenceYear ?? Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        try store.confirmedOfferSyncEntries().compactMap { entry in
            guard entry.nettoEur > 0 else { return nil }
            guard let reason = entry.offerStatus.learningReason(kind: entry.offerKind) else { return nil }

            let offerYear = OfferAnchorInflation.year(from: entry.offerDate)
            let inflation = OfferAnchorInflation.factor(offerYear: offerYear, referenceYear: referenceYear)
            let presentValue = entry.nettoEur * inflation
            let confidence = LearningStore.baseConfidence(for: reason)
                * OfferAnchorInflation.confidenceFactor(offerYear: offerYear, referenceYear: referenceYear)

            let jahr = offerYear.map(String.init) ?? "o. J."
            let quote = "Bestätigtes eingehendes Angebot \(entry.partner), \(jahr), netto \(presentValue) EUR (gegenwartsnormiert)."

            return CandidateReleaseDecision(
                candidateID: "LEARNED-\(entry.airtableRecordID)",
                sourceFile: "Airtable · Eingehende-Angebote",
                page: 0,
                supplier: entry.partner,
                project: "",
                component: "Gesamtküche \(entry.partner)",
                trade: reason.displayName,
                priceNetGuess: presentValue,
                confidence: confidence,
                duplicateCount: 0,
                currentStatus: "release_candidate",
                proposedStatus: "release_candidate",
                supersededBy: nil,
                decisionScore: confidence,
                decisionReason: "learned_incoming_offer",
                helpNeeded: "",
                title: "Eingehendes Angebot \(entry.partner)",
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

public struct CompositeAnchorProvider: PriceAnchorProviding {
    private let primary: PriceAnchorProviding
    private let learned: PriceAnchorProviding

    private let pdfLearned: PriceAnchorProviding?

    public init(primary: PriceAnchorProviding, learned: PriceAnchorProviding,
                pdfLearned: PriceAnchorProviding? = nil) {
        self.primary = primary
        self.learned = learned
        self.pdfLearned = pdfLearned
    }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        let base = try primary.activeAnchors()
        return base + orEmpty(learned) + (pdfLearned.map(orEmpty) ?? [])
    }

    private func orEmpty(_ provider: PriceAnchorProviding) -> [CandidateReleaseDecision] {
        (try? provider.activeAnchors()) ?? []
    }
}
