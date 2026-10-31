import Core
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

struct BottomUpCostEngine: Sendable {
    func estimate(components: [EstimateComponent]) -> BottomUpEstimate {
        var carcasses = 0.0
        var frontArea = 0.0
        let materials = components.reduce(into: Set<String>()) { $0.formUnion($1.materials) }

        for component in components {
            switch component.componentClass {
            case .kitchenRun:
                carcasses += component.quantity / CostModel.carcassWidthM
                frontArea += component.quantity * CostModel.baseFrontHeightM
            case .baseUnit:
                let width = component.widthM ?? (component.unit == "piece" ? 0.6 : component.quantity)
                carcasses += max(1.0, width / CostModel.carcassWidthM)
                frontArea += width * CostModel.baseFrontHeightM
            case .tallCabinetBlock:
                let width = component.widthM ?? component.quantity
                let height = component.heightM ?? 2.0
                carcasses += max(1.0, width / CostModel.carcassWidthM)
                frontArea += width * height
            case .island:
                let width = component.widthM ?? (component.unit == "m2" ? max(1.2, component.quantity.squareRoot()) : component.quantity)
                carcasses += (width / CostModel.carcassWidthM) * 1.6
                frontArea += width * 0.9 * 1.5
            default:
                continue
            }
        }

        guard carcasses > 0 else {
            return BottomUpEstimate(laborNet: 0, materialNet: 0, total: 0, carcassEquivalents: 0,
                                    frontAreaM2: 0, stageBreakdown: [], assumptions: [])
        }

        let carcassDecimal = Decimal(finite: carcasses)
        var stageBreakdown: [StageCost] = []
        var labor = Decimal(0)
        for stage in CostModel.stages {
            let perCarcass = stage.ratePerHour * Decimal(finite: stage.minutesPerCarcass / 60)
            let cost = perCarcass * carcassDecimal
            labor += cost
            stageBreakdown.append(StageCost(stage: stage.key, minutesPerCarcass: stage.minutesPerCarcass,
                                            ratePerHour: stage.ratePerHour, cost: cost))
        }

        let carcassMaterial = carcassDecimal * Decimal(finite: CostModel.carcassSurfaceM2) * CostModel.decorBoardPerM2
        let front = CostModel.frontPrice(materials: materials)
        let frontMaterial = Decimal(finite: frontArea) * front.price
        let material = carcassMaterial + frontMaterial

        let assumptions = [
            Notice("calc.bottomUp.carcassEquivalent", [String(CostModel.carcassWidthM)]),
            Notice("calc.bottomUp.labor", [Notice.amount(CostModel.laborPerCarcass)]),
            Notice("calc.bottomUp.carcassMaterial", [String(CostModel.carcassSurfaceM2), Notice.amount(CostModel.decorBoardPerM2)]),
            Notice("calc.bottomUp.front", [front.materialKey, Notice.amount(front.price), Notice.fixed(frontArea, digits: 1)]),
            Notice("calc.bottomUp.floor"),
        ]
        return BottomUpEstimate(laborNet: labor, materialNet: material, total: labor + material,
                                carcassEquivalents: carcasses, frontAreaM2: frontArea,
                                stageBreakdown: stageBreakdown, assumptions: assumptions)
    }
}

struct ScopeDensityEngine: Sendable {
    private let densityByCandidate: [String: EquipmentDensity]

    init(densityByCandidate: [String: EquipmentDensity]) {
        self.densityByCandidate = densityByCandidate
    }

    init(csv: String) {
        guard let table = try? CSVTable(data: csv, lenient: true) else {
            self.init(densityByCandidate: [:])
            return
        }
        var map: [String: EquipmentDensity] = [:]
        for row in table.rows {
            let id = row.string("candidate_id")
            guard id.isEmpty == false else { continue }
            let density = EquipmentDensity(rawCorpus: row.string("equipment_density"))
            guard density != .unknown else { continue }
            map[id] = density
        }
        self.init(densityByCandidate: map)
    }

    func enrich(_ anchors: [CandidateReleaseDecision]) -> [CandidateReleaseDecision] {
        guard densityByCandidate.isEmpty == false else { return anchors }
        return anchors.map { anchor in
            let density = densityByCandidate[anchor.candidateID] ?? .unknown
            return density == .unknown ? anchor : anchor.withEquipmentDensity(density)
        }
    }
}

enum StochasticEngine {
    struct Component: Equatable {
        let median: Double
        let sigma: Double

        init(median: Double, sigma: Double) {
            self.median = median
            self.sigma = max(0, sigma)
        }
    }

    struct Summary: Equatable {
        let low: Double
        let median: Double
        let mean: Double
        let high: Double

        var relativeWidth: Double { median > 0 ? (high - low) / (2 * median) : 1 }
    }

    static let defaultCorrelation: Double = 0.35
    static let defaultDraws: Int = 20_000
    static let defaultSeed: UInt64 = 0x5EED_1234_ABCD_0001

    static func aggregate(
        components: [Component],
        correlation: Double = defaultCorrelation,
        draws: Int = defaultDraws,
        seed: UInt64 = defaultSeed
    ) -> Summary {
        let active = components.filter { $0.median > 0 }

        let medianSum = active.reduce(0.0) { $0 + $1.median }
        guard !active.isEmpty else {
            return Summary(low: 0, median: 0, mean: 0, high: 0)
        }

        let deterministic = active.filter { $0.sigma == 0 }.reduce(0.0) { $0 + $1.median }
        let stochastic = active.filter { $0.sigma > 0 }
        guard !stochastic.isEmpty else {
            return Summary(low: medianSum, median: medianSum, mean: medianSum, high: medianSum)
        }

        let rho = min(1, max(0, correlation))
        let sqrtRho = rho.squareRoot()
        let sqrtOneMinusRho = (1 - rho).squareRoot()

        var rng = SeededRandom(seed: seed)
        var totals = [Double]()
        totals.reserveCapacity(draws)
        var sumForMean = 0.0

        for _ in 0..<draws {
            let common = rng.nextStandardNormal()
            var sum = deterministic
            for component in stochastic {
                let idio = rng.nextStandardNormal()
                let z = sqrtRho * common + sqrtOneMinusRho * idio
                sum += component.median * exp(component.sigma * z)
            }
            totals.append(sum)
            sumForMean += sum
        }

        totals.sort()
        return Summary(
            low: percentile(sorted: totals, p: 0.10),
            median: percentile(sorted: totals, p: 0.50),
            mean: sumForMean / Double(draws),
            high: percentile(sorted: totals, p: 0.90)
        )
    }

    static func confidence(evidenceScore: Double, relativeWidth: Double) -> Double {
        let bandPrecision = max(0.1, min(1.0, 1.0 - relativeWidth))
        let blended = (max(0, evidenceScore) * bandPrecision).squareRoot()
        return max(0.1, min(0.95, blended))
    }

    static func sigma(fromRelativeSpread spread: Double) -> Double {
        let clamped = min(0.95, max(0, spread))
        guard clamped > 0 else { return 0 }
        let ratio = (1 + clamped) / (1 - clamped)
        return log(ratio) / (2 * 1.2816)
    }

    static func percentile(sorted: [Double], p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        if sorted.count == 1 { return sorted[0] }
        let rank = p * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let frac = rank - Double(lower)
        return sorted[lower] * (1 - frac) + sorted[upper] * frac
    }
}

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextUnitInterval() -> Double {
        let bits = next() >> 11
        return (Double(bits) + 0.5) / Double(1 << 53)
    }

    mutating func nextStandardNormal() -> Double {
        let u1 = nextUnitInterval()
        let u2 = nextUnitInterval()
        return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
}

struct EvidenceEngine: Sendable {
    private let resolver = ComponentResolveEngine()
    private let components = ComponentEstimateEngine()

    func estimate(_ request: EstimateInput, anchors: [CandidateReleaseDecision], factors: [ActiveFactor]) -> EstimateResult {
        let requirements = resolver.resolve(request)
        var lines: [EstimateLine] = []
        var allEvidence: [EvidenceCase] = []
        var dataGaps: [Notice] = []

        var missingComponents = 0

        for requirement in requirements {
            let candidates = components.selectCandidates(for: requirement, anchors: anchors)
            if candidates.count < requirement.minEvidenceCount {
                dataGaps.append(Notice("calc.gap.evidenceShort", [String(candidates.count), String(requirement.minEvidenceCount), requirement.component.type.localizationKey]))
            }
            guard !candidates.isEmpty else { missingComponents += 1; continue }

            let chosen = Array(candidates.prefix(5))
            let evidence = chosen.map { components.evidenceCase(from: $0) }
            let expected = components.price(requirement: requirement, candidates: chosen)
            let spread = components.spreadFactor(for: requirement, evidenceCount: chosen.count, candidates: chosen)
            let band = PriceBand(
                low: expected * (Decimal(1) - spread),
                expected: expected,
                high: expected * (Decimal(1) + spread),
                currency: "EUR"
            )
            lines.append(EstimateLine(
                id: UUID(),
                component: requirement.component,
                priceBand: band,
                evidence: evidence,
                rationale: components.rationale(for: requirement, evidenceCount: evidence.count)
            ))
            allEvidence.append(contentsOf: evidence)
        }

        let stochasticComponents: [StochasticEngine.Component] = lines.map { line in
            let expectedD = line.priceBand.expected.double
            let highD = line.priceBand.high.double
            let spread = expectedD > 0 ? max(0, (highD - expectedD) / expectedD) : 0
            return .init(median: expectedD, sigma: StochasticEngine.sigma(fromRelativeSpread: spread))
        }
        let aggregate = StochasticEngine.aggregate(components: stochasticComponents)
        let expected = Decimal(aggregate.mean.rounded())
        let baseTotal = PriceBand(
            low: Decimal(aggregate.low.rounded()),
            expected: expected,
            high: Decimal(aggregate.high.rounded()),
            currency: "EUR"
        )
        let implausible = requirements.filter { $0.component.scopeNotes.contains(.sizeImplausible) }
        for requirement in implausible {
            dataGaps.append(Notice("calc.gap.sizeImplausible", [requirement.component.type.localizationKey]))
        }

        let evidenceConfidence = allEvidence.isEmpty ? 0.2 : allEvidence.map(\.confidence).reduce(0, +) / Double(allEvidence.count)
        let evidenceScore = max(0.1, min(0.95, evidenceConfidence - Double(dataGaps.count) * 0.04))
        var confidence = StochasticEngine.confidence(evidenceScore: evidenceScore, relativeWidth: aggregate.relativeWidth)

        if !implausible.isEmpty { confidence = min(confidence, 0.35) }

        if missingComponents > 0 {
            confidence = max(0.1, confidence * pow(0.6, Double(missingComponents)))
            dataGaps.append(Notice("calc.gap.missingComponents", [String(missingComponents)]))
        }
        let baseLaborValue = expected * Decimal(string: "0.42")!
        let excluded = [
            Notice("calc.excluded.atomic"),
            Notice("calc.excluded.carryover"),
            Notice("calc.excluded.netTotal"),
            Notice("calc.excluded.vat"),
            Notice("calc.excluded.alternative"),
        ]
        let scopeNotes = request.scope.notes.isEmpty ? [Notice("calc.scope.default")] : request.scope.notes
        let calibration = applyActiveFactors(baseTotal: baseTotal, lines: lines, factors: factors)
        let laborValue = calibration.total.expected * Decimal(string: "0.42")!

        let bottomUp = BottomUpCostEngine().estimate(components: requirements.map(\.component))
        if bottomUp.total > 0 {
            let floorEUR = bottomUp.total.double
            let ratio = calibration.total.expected.double / floorEUR
            if ratio < 0.95 {
                dataGaps.append(Notice("calc.gap.belowFloor", [String(Int(floorEUR.rounded()))]))
            }
        }

        return EstimateResult(
            request: request,
            lines: lines,
            totalBand: calibration.total,
            laborValue: laborValue,
            confidence: confidence,
            evidence: Array(allEvidence.prefix(12)),
            dataGaps: dataGaps,
            excludedRisks: excluded,
            scopeNotes: scopeNotes,
            baseTotalBand: baseTotal,
            baseLaborValue: baseLaborValue,
            calibrationApplications: calibration.applications,
            bottomUpCost: bottomUp
        )
    }

    private func applyActiveFactors(baseTotal: PriceBand, lines: [EstimateLine], factors all: [ActiveFactor]) -> (total: PriceBand, applications: [AppliedFactor]) {
        let factors = all.filter { $0.status == .active }
        guard !factors.isEmpty, baseTotal.expected > 0 else { return (baseTotal, []) }

        var finalExpected = baseTotal.expected
        var applications: [AppliedFactor] = []
        for factor in factors {
            let basis: Decimal
            if factor.target == .wholeEstimate {
                basis = baseTotal.expected
            } else {
                basis = lines
                    .filter { factor.target.matches(component: $0.component) }
                    .map(\.priceBand.expected)
                    .reduce(Decimal(0), +)
            }
            guard basis > 0 else { continue }
            let delta = basis * (factor.multiplier - Decimal(1))
            finalExpected += delta
            applications.append(AppliedFactor(
                factorID: factor.id,
                reason: factor.reason,
                target: factor.target,
                multiplier: factor.multiplier,
                appliedDeltaNet: delta
            ))
        }
        guard finalExpected > 0 else { return (baseTotal, applications) }
        let ratio = finalExpected / baseTotal.expected
        return (
            PriceBand(
                low: baseTotal.low * ratio,
                expected: finalExpected,
                high: baseTotal.high * ratio,
                currency: baseTotal.currency
            ),
            applications
        )
    }
}

public struct SeedAnchors: PriceAnchorPort {
    public init() {}

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        Self.all()
    }

    static func all() -> [CandidateReleaseDecision] {
        [
            baseline(
                id: "BASE_UC_060_DOOR_SHELF",
                component: "60cm Unterschrank Tür/Fachboden",
                price: 820,
                title: "Konservativer Baseline-Anker für 60cm Unterschrank mit Tür und Fachboden.",
                quote: "Manuell gepflegter Seed-Regelanker; nur für atomare Unterschrank-Anfragen, nicht aus PDF-Angebot.",
                componentClass: .baseUnit
            ),
            baseline(
                id: "BASE_UC_060_DRAWERS_SIMPLE",
                component: "60cm Unterschrank einfache Schübe",
                price: 1250,
                title: "Konservativer Baseline-Anker für 60cm Unterschrank mit einfachen Schubkästen.",
                quote: "Manuell gepflegter Seed-Regelanker; verhindert Skalierung von Küchenaggregaten auf Einzelmöbel.",
                componentClass: .baseUnit
            ),
            baseline(
                id: "BASE_DRAWER_LEGRABOX",
                component: "Legrabox Schubkasten",
                price: 180,
                title: "Legrabox-Schubkasten als atomarer Beschlagsanker.",
                quote: "Manuell gepflegter Seed-Regelanker je Schubkasten.",
                componentClass: .baseUnit
            ),
            baseline(
                id: "BASE_DRAWER_OAK_UPCHARGE",
                component: "Eichenschubkasten Aufpreis",
                price: 140,
                title: "Eiche-Aufpreis pro Schubkasten.",
                quote: "Manuell gepflegter Seed-Regelanker je Eichenschubkasten.",
                componentClass: .baseUnit
            ),
            baseline(
                id: "BASE_LINOL_FRONT_PER_LFM",
                component: "Linoleumfront pro Laufmeter",
                price: 680,
                title: "Linoleumfronten als konservativer Laufmeter-Aufpreis.",
                quote: "Manuell gepflegter Seed-Regelanker je Laufmeter Front.",
                componentClass: .kitchenRun
            ),
            baseline(
                id: "BASE_STAINLESS_FRONT_PER_M2",
                component: "Edelstahlfront pro Quadratmeter",
                price: 950,
                title: "Edelstahlfronten als konservativer Quadratmeter-Aufpreis.",
                quote: "Manuell gepflegter Seed-Regelanker je Quadratmeter Edelstahlfront.",
                componentClass: .island
            ),
        ]
    }

    private static func baseline(id: String, component: String, price: Decimal, title: String, quote: String, componentClass: ComponentClass) -> CandidateReleaseDecision {
        CandidateReleaseDecision(
            candidateID: id,
            sourceFile: "RULE_BASED_SEED",
            page: 0,
            supplier: "calc.seed.supplier",
            project: "Baseline",
            component: component,
            trade: "Seed-Regel",
            priceNetGuess: price,
            confidence: 0.62,
            duplicateCount: 1,
            currentStatus: "active",
            proposedStatus: "release_rule_based",
            supersededBy: nil,
            decisionScore: 0.62,
            decisionReason: "Konservativer Baseline-Atom, weil PDF-Korpus keinen ausreichend sauberen atomaren Anker liefert.",
            helpNeeded: "",
            title: title,
            evidenceQuote: quote,
            carryforwardRuleStatus: "not_applicable",
            ruleSafePriceNet: price,
            ruleNotes: "rule_based_anchor; no_delete_policy; nicht aus PDF-Angebot.",
            componentClass: componentClass,
            sourceKind: .ruleBasedAnchor
        )
    }
}
