import Foundation
import Storage

public actor EstimationEngine: EstimationPort {
    static let carcassConfidence = 0.65
    static let noProjectID = "no-project"
    static let assumedCarcassCount = 7

    private let anchors: any PriceAnchorPort
    private let learningStore: LearningStore
    private let articlePrices: (any ArticlePricePort)?
    private let devicePrices: (any ArticlePricePort)?
    private let auditStore: AuditStore?
    private let parameterPort: (any CarcassParameterPort)?
    private let workshopFactors: WorkshopFactors
    private let actorUserID: String
    private let maxEvidence: Int
    private let parser = EstimateRequestParser()
    private let evidenceEngine = EvidenceEngine()

    private var parametersCache: CarcassParameters?
    private var projectIDBySession: [String: String] = [:]

    public init(
        anchors: any PriceAnchorPort,
        learningStore: LearningStore,
        articlePrices: (any ArticlePricePort)? = nil,
        devicePrices: (any ArticlePricePort)? = nil,
        auditStore: AuditStore? = nil,
        parameterPort: (any CarcassParameterPort)? = nil,
        workshopFactors: WorkshopFactors = WorkshopFactors(),
        actorUserID: String = "local-user",
        maxEvidence: Int = 5
    ) {
        self.anchors = anchors
        self.learningStore = learningStore
        self.articlePrices = articlePrices
        self.devicePrices = devicePrices
        self.auditStore = auditStore
        self.parameterPort = parameterPort
        self.workshopFactors = workshopFactors
        self.actorUserID = actorUserID
        self.maxEvidence = maxEvidence
    }

    public func estimate(projectID: String?, text: String, override: EstimateOverride = EstimateOverride()) async throws -> CostEstimate {
        let request = parser.parse(text)
        if Self.isKitchen(request) || override.carcassCount != nil {
            return try await estimateKitchen(request, projectID: projectID, override: override)
        }
        let activeAnchors = try anchors.activeAnchors()
        let result = evidenceEngine.estimate(request, anchors: activeAnchors, factors: try learningStore.activeFactors())
        let session = try learningStore.saveSession(from: result)
        if let projectID { projectIDBySession[session.id] = projectID }
        return Self.map(result, estimateID: session.id, projectID: projectID ?? Self.noProjectID, maxEvidence: maxEvidence)
    }

    static func isKitchen(_ request: EstimateInput) -> Bool {
        let text = request.rawText.lowercased()
        if text.contains("küche") || text.contains("kueche") || text.contains("kitchen") { return true }
        if request.components.contains(where: { [.kitchenRun, .island, .aggregateKitchen].contains($0.componentClass) }) { return true }
        let singleCarcasses = request.components.filter { [.baseUnit, .tallCabinetBlock].contains($0.componentClass) }.count
        return singleCarcasses >= 2
    }

    private func estimateKitchen(_ request: EstimateInput, projectID: String?, override: EstimateOverride) async throws -> CostEstimate {
        let engine = CarcassEngine(params: await carcassParameters())
        var spec = engine.spec(components: request.components, scope: request.scope, distanceKm: override.distanceKm)
        var sizeHint: Notice?

        if let count = override.carcassCount, count > 0 { spec.carcassCount = count }
        if let frontExecution = override.frontExecution {
            spec.frontExecution = FrontExecution(rawValue: frontExecution.lowercased())
                ?? FrontExecution.infer(from: [frontExecution])
        }
        if let legrabox = override.drawersLegrabox, legrabox >= 0 { spec.drawersLegrabox = legrabox }
        if let solid = override.drawersSolid, solid >= 0 { spec.drawersSolid = solid }
        if let workshop = override.workshop { spec.workshop = workshop }

        if spec.carcassCount < 1 {
            spec.carcassCount = Self.assumedCarcassCount
            sizeHint = Notice("calc.hint.sizeMissing")
        }
        let carcass = engine.estimate(spec)

        let result = EstimateResult(
            request: request, lines: [], totalBand: carcass.band, laborValue: carcass.installationShare,
            confidence: Self.carcassConfidence, evidence: [], dataGaps: [],
            excludedRisks: carcass.excludes.map(\.detail), scopeNotes: carcass.assumptions)
        let session = try learningStore.saveSession(from: result)

        try learningStore.saveCarcassSnapshot(sessionID: session.id, snapshot: carcass.parameterSnapshot)
        if let projectID { projectIDBySession[session.id] = projectID }
        return Self.mapCarcass(carcass, estimateID: session.id, projectID: projectID ?? Self.noProjectID,
                               sizeHint: sizeHint, openFields: override.openFields)
    }

    private func carcassParameters() async -> CarcassParameters {
        if let cached = parametersCache { return cached }
        let loaded = await parameterPort?.parameters() ?? CarcassParameters.seed(workshopFactors: workshopFactors)
        parametersCache = loaded
        return loaded
    }

    func devicePrice(term: String) async -> Double? {
        if let articlePrices, let live = await articlePrices.purchaseNet(matching: term) {
            return live
        }
        return await devicePrices?.purchaseNet(matching: term)
    }

    func recordAdjustment(estimateID: String, factor: Double, ground: String, learn: Bool = false) async throws {
        let percentDelta = (factor - 1) * 100

        _ = try learningStore.appendAdjustment(
            sessionID: estimateID,
            percentDelta: percentDelta,
            euroDelta: nil,
            reason: .gutFeeling,
            target: .wholeEstimate,
            learn: learn,
            note: ground
        )

        guard let auditStore else { return }
        let projectID = projectIDBySession[estimateID] ?? estimateID
        let summary = Notice("calc.audit.adjusted", [String(Int(abs(percentDelta).rounded())), Self.directionKey(percentDelta), ground])
        try await auditStore.append(AuditEntry(
            actorUserID: actorUserID, projectID: projectID, action: .estimateAdjusted, summary: summary.json))
    }

    func learningSnapshot() async throws -> LearningSnapshot {
        let summary = try learningStore.summary()
        let factors = summary.activeFactors.map { factor in
            EstimationFactor(id: factor.id, reason: factor.reason, target: factor.target,
                             percent: factor.weightedPercentDelta, sampleCount: factor.sampleCount, status: factor.status)
        }
        let candidates = summary.candidates
            .filter { $0.status == .candidate || $0.status == .strongCandidate }
            .map { candidate in
                EstimationFactor(id: candidate.id, reason: candidate.reason, target: candidate.target,
                                 percent: candidate.weightedPercentDelta, sampleCount: candidate.sampleCount, status: candidate.status)
            }
        return LearningSnapshot(sessions: summary.sessions, adjustments: summary.adjustments, outliers: summary.outliers,
                                activeFactors: factors, candidates: candidates)
    }

    func promote(candidateID: String) async throws {
        let factor = try learningStore.promoteCalibration(candidateID: candidateID)

        guard let auditStore else { return }
        let summary = Notice("calc.audit.promoted", [
            factor.reason.localizationKey, factor.target.localizationKey,
            String(Int(abs(factor.weightedPercentDelta).rounded())), Self.directionKey(factor.weightedPercentDelta),
            String(factor.sampleCount),
        ])
        try await auditStore.append(AuditEntry(
            actorUserID: actorUserID, projectID: "calculation", action: .calibrationPromoted, summary: summary.json))
    }

    func recordCarcassCorrection(estimateID: String, targetKey: String, observedNet: Double, reason: AdjustmentReason, note: String, learn: Bool) async throws {
        guard let target = CarcassCalibrationTarget(key: targetKey) else {
            throw LearningFailure.unknownCarcassTarget(targetKey)
        }
        let adjustment = try learningStore.appendCarcassAdjustment(
            sessionID: estimateID, target: target, observedValue: observedNet,
            reason: reason, note: note, learn: learn)

        guard let auditStore else { return }
        let projectID = projectIDBySession[estimateID] ?? estimateID
        let summary = Notice("calc.audit.carcassCorrected", [
            target.localizationKey, target.detail, String(Int(abs(adjustment.percentDelta).rounded())),
            Self.directionKey(adjustment.percentDelta), note.isEmpty ? reason.localizationKey : note,
        ])
        try await auditStore.append(AuditEntry(
            actorUserID: actorUserID, projectID: projectID, action: .estimateAdjusted, summary: summary.json))
    }

    static func directionKey(_ percentDelta: Double) -> String {
        if abs(percentDelta).rounded() == 0 { return "calc.direction.unchanged" }
        return percentDelta > 0 ? "calc.direction.higher" : "calc.direction.cheaper"
    }

    static func map(_ result: EstimateResult, estimateID: String, projectID: String, maxEvidence: Int) -> CostEstimate {
        let mid = result.totalBand.expected.double
        let floor = (result.bottomUpCost?.total ?? 0).double
        let topEvidence = result.evidence.prefix(maxEvidence).map { evidence in
            PriceEvidence(
                supplier: evidence.supplier,
                document: evidence.sourceFile,
                page: evidence.page,
                originalQuote: evidence.quote,
                netPrice: evidence.netPrice.double
            )
        }
        return CostEstimate(
            estimateID: estimateID,
            projectID: projectID,
            minNet: result.totalBand.low.double,
            maxNet: result.totalBand.high.double,
            midNet: mid,
            confidence: result.confidence,
            evidenceCount: result.evidence.count,
            costFloor: floor,
            costFloorRatio: mid > 0 ? floor / mid : 0,
            topEvidence: Array(topEvidence)
        )
    }

    static func mapCarcass(_ estimate: CarcassEstimate, estimateID: String, projectID: String,
                           sizeHint: Notice?, openFields: [String]) -> CostEstimate {
        var hints: [Notice] = []
        if let sizeHint { hints.append(sizeHint) }
        hints.append(contentsOf: estimate.assumptions)
        hints.append(contentsOf: estimate.excludes.map(\.hint))
        if openFields.isEmpty == false {
            hints.append(Notice("calc.hint.openFields", openFields))
        }

        var lines: [EstimateBreakdownLine] = [
            EstimateBreakdownLine(label: Notice("calc.line.furniture"), amountNet: estimate.furnitureWithoutInstallation.double, kind: .estimated),
            EstimateBreakdownLine(label: Notice("calc.line.installation"), amountNet: estimate.installationShare.double, kind: .estimated),
        ]
        lines.append(contentsOf: estimate.excludes.map { EstimateBreakdownLine(label: $0.label, amountNet: nil, kind: .open) })

        return CostEstimate(
            estimateID: estimateID,
            projectID: projectID,
            minNet: estimate.band.low.double,
            maxNet: estimate.band.high.double,
            midNet: estimate.band.expected.double,
            confidence: carcassConfidence,
            evidenceCount: 0,
            costFloor: 0,
            costFloorRatio: 0,
            topEvidence: [],
            modelLabel: Notice("calc.model.carcass"),
            hints: hints,
            lines: lines,
            excludes: estimate.excludes.map(\.detail))
    }
}
