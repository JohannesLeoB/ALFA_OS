import Foundation
import MykilosKit
import MykilosKalkulationsCore

public protocol ArticlePriceLookup: Sendable {
    func purchaseNet(matching term: String) async -> Double?
}

public actor KalkulationsEngine: KalkulationsEngineProviding {
    private let provider: PriceAnchorProviding
    private let learningStore: LearningStore
    private let deviceCatalog: DeviceCatalog?
    private let articlePrices: (any ArticlePriceLookup)?
    private let auditStore: AuditStore?
    private let parser = EstimateRequestParser()
    private let maxEvidences: Int

    private let korpusParamProvider: SchaetzmodellParameterProvider
    private var korpusParamsCache: KorpusModelParameters?

    private let schaetzmodellSchreiber: SchaetzmodellSchreiber

    private var projektIDBySession: [String: String] = [:]

    private static let keinProjektSentinel = "kein-projekt"

    public init(
        provider: PriceAnchorProviding,
        learningStore: LearningStore,
        deviceCatalog: DeviceCatalog? = nil,
        articlePrices: (any ArticlePriceLookup)? = nil,
        auditStore: AuditStore? = nil,
        maxEvidences: Int = 5,
        korpusParamProvider: SchaetzmodellParameterProvider = SchaetzmodellParameterProvider(),
        schaetzmodellSchreiber: SchaetzmodellSchreiber = SchaetzmodellSchreiber()
    ) {
        self.provider = provider
        self.learningStore = learningStore
        self.deviceCatalog = deviceCatalog
        self.articlePrices = articlePrices
        self.auditStore = auditStore
        self.maxEvidences = maxEvidences
        self.korpusParamProvider = korpusParamProvider
        self.schaetzmodellSchreiber = schaetzmodellSchreiber
    }

    enum Schaetzmodell: Sendable { case auto, ankerErzwungen }

    public func schaetze(projektID: String?, freitext: String) async throws -> KostenSchaetzung {
        try await schaetze(projektID: projektID, freitext: freitext, modell: .auto, override: EstimateOverride())
    }

    public func schaetze(projektID: String?, freitext: String,
                         override: EstimateOverride) async throws -> KostenSchaetzung {
        try await schaetze(projektID: projektID, freitext: freitext, modell: .auto, override: override)
    }

    func schaetze(projektID: String?, freitext: String, modell: Schaetzmodell,
                  override: EstimateOverride = EstimateOverride()) async throws -> KostenSchaetzung {
        let request = parser.parse(freitext)

        if modell == .auto && (Self.istKueche(request) || override.korpusCount != nil) {
            return try await schaetzeKueche(request, projektID: projektID, override: override)
        }
        let estimator = EvidenceBasedEstimator(provider: provider, calibrationProvider: learningStore)
        let result = try estimator.estimate(request)

        let session = try learningStore.saveSession(from: result)

        if let projektID { projektIDBySession[session.id] = projektID }
        return Self.map(result, schaetzungsID: session.id, projektID: projektID ?? Self.keinProjektSentinel, maxEvidences: maxEvidences)
    }

    static func istKueche(_ request: EstimateRequest) -> Bool {
        let t = request.rawText.lowercased()
        if t.contains("küche") || t.contains("kueche") || t.contains("kitchen") { return true }
        if request.components.contains(where: { [.kitchenRun, .island, .aggregateKitchen].contains($0.componentClass) }) { return true }
        let korpusEinzel = request.components.filter { [.baseUnit, .tallCabinetBlock].contains($0.componentClass) }.count
        return korpusEinzel >= 2
    }

    static let korpusKonfidenz = 0.65

    private func schaetzeKueche(_ request: EstimateRequest, projektID: String?,
                                override: EstimateOverride = EstimateOverride()) async throws -> KostenSchaetzung {
        let params = await korpusParameter()
        let estimator = KorpusBandEstimator(params: params)
        var spec = estimator.spec(components: request.components, scope: request.scope,
                                  distanceKm: override.distanceKm)
        var groessenHinweis: String?

        if let count = override.korpusCount, count > 0 { spec.korpusCount = count }
        if let frontExecution = override.frontExecution {
            spec.frontExecution = FrontExecution(rawValue: frontExecution.lowercased())
                ?? FrontExecution.infer(from: [frontExecution])
        }
        if let legrabox = override.drawersLegrabox, legrabox >= 0 { spec.drawersLegrabox = legrabox }
        if let holz = override.drawersHolz, holz >= 0 { spec.drawersHolz = holz }
        if let workshop = override.workshop { spec.werkstatt = workshop }

        if spec.korpusCount < 1 {
            spec.korpusCount = 7
            groessenHinweis = "⚠️ Größe fehlt — als typische mittlere Küche (~7 Korpen) angenommen. Bitte Laufmeter oder Korpuszahl nennen für eine belastbare Schätzung."
        }
        let korpus = estimator.estimate(spec)

        let er = EstimateResult(
            request: request, lines: [], totalBand: korpus.band, laborValue: korpus.montageAnteil,
            confidence: Self.korpusKonfidenz, evidence: [], dataGaps: [],
            excludedRisks: korpus.excludes, scopeNotes: korpus.assumptions)
        let session = try learningStore.saveSession(from: er)

        try learningStore.saveKorpusSnapshot(sessionID: session.id, snapshot: korpus.parameterSnapshot)
        if let projektID { projektIDBySession[session.id] = projektID }
        return Self.mapKorpus(korpus, schaetzungsID: session.id,
                              projektID: projektID ?? Self.keinProjektSentinel,
                              groessenHinweis: groessenHinweis, openFields: override.openFields)
    }

    private func korpusParameter() async -> KorpusModelParameters {
        if let c = korpusParamsCache { return c }
        let p = await korpusParamProvider.load()
        korpusParamsCache = p
        return p
    }

    public func geraetepreis(suchbegriff: String) async -> Double? {
        if let articlePrices, let live = await articlePrices.purchaseNet(matching: suchbegriff) {
            return live
        }
        guard let deviceCatalog else { return nil }
        guard let best = deviceCatalog.search(suchbegriff, limit: 1).first,
              let preis = best.purchaseNet else { return nil }
        return Self.double(preis)
    }

    public func recordAdjustment(schaetzungsID: String, faktor: Double, ground: String, lernen: Bool = false) async throws {
        let percentDelta = (faktor - 1) * 100

        _ = try learningStore.appendAdjustment(
            sessionID: schaetzungsID,
            percentDelta: percentDelta,
            euroDelta: nil,
            reason: .gutFeeling,
            target: .wholeEstimate,
            learn: lernen,
            note: ground
        )

        guard let auditStore else { return }
        let projektID = projektIDBySession[schaetzungsID] ?? schaetzungsID
        let prozent = abs(percentDelta).rounded()
        let richtung = percentDelta >= 0 ? "höher" : "günstiger"
        let summary = "Schätzung \(Int(prozent)) % \(richtung) angepasst (\(ground))"
        let entry = AuditEntry(
            actorUserID: "local-user",
            projectID: projektID,
            action: .estimateAdjusted,
            summary: summary
        )
        try await auditStore.append(entry)
    }

    public func lernUebersicht() async throws -> KalkulationsLernStand {
        Self.mapLernStand(try learningStore.summary())
    }

    public func promote(candidateID: String) async throws {
        let factor = try learningStore.promoteCalibration(candidateID: candidateID)

        guard let auditStore else { return }
        let prozent = abs(factor.weightedPercentDelta).rounded()
        let richtung = factor.weightedPercentDelta >= 0 ? "höher" : "günstiger"
        let summary = "Kalibrierung übernommen: \(factor.reason.displayName) · \(factor.target.displayName) · "
            + "\(Int(prozent)) % \(richtung) (n=\(factor.sampleCount))"
        let entry = AuditEntry(
            actorUserID: "local-user",
            projectID: "kalkulation",
            action: .calibrationPromoted,
            summary: summary
        )
        try await auditStore.append(entry)
    }

    public func recordKorpusKorrektur(
        schaetzungsID: String, ziel: KorpusKalibrierZiel, beobachteterWertNetto: Double,
        reason: EstimateAdjustmentReason, note: String = "", lernen: Bool = false
    ) async throws -> KorpusAdjustment {
        let adjustment = try learningStore.appendKorpusAdjustment(
            sessionID: schaetzungsID, ziel: ziel, beobachteterWert: beobachteterWertNetto,
            reason: reason, note: note, learn: lernen)

        guard let auditStore else { return adjustment }
        let projektID = projektIDBySession[schaetzungsID] ?? schaetzungsID
        let prozent = abs(adjustment.percentDelta).rounded()
        let richtung = adjustment.percentDelta >= 0 ? "höher" : "günstiger"
        let entry = AuditEntry(
            actorUserID: "local-user", projectID: projektID, action: .estimateAdjusted,
            summary: "Korpus-Modell \(ziel.displayName) \(Int(prozent)) % \(richtung) korrigiert (\(note.isEmpty ? reason.displayName : note))"
        )
        try await auditStore.append(entry)
        return adjustment
    }

    static func mapLernStand(_ summary: LearningSummary) -> KalkulationsLernStand {
        let faktoren = summary.activeFactors.map { factor in
            KalkulationsFaktor(
                id: factor.id,
                grundLabel: factor.reason.displayName,
                zielLabel: factor.target.displayName,
                prozent: factor.weightedPercentDelta,
                sampleCount: factor.sampleCount
            )
        }

        let candidates = summary.candidates
            .filter { $0.status == .candidate || $0.status == .strongCandidate }
            .map { candidate in
                KalkulationsKandidat(
                    id: candidate.id,
                    grundLabel: candidate.reason.displayName,
                    zielLabel: candidate.target.displayName,
                    prozent: candidate.weightedPercentDelta,
                    sampleCount: candidate.sampleCount,
                    statusLabel: candidate.status == .strongCandidate ? "Starker Kandidat" : "Kandidat"
                )
            }
        return KalkulationsLernStand(
            sessions: summary.sessions,
            adjustments: summary.adjustments,
            outliers: summary.outliers,
            aktiveFaktoren: faktoren,
            candidates: candidates
        )
    }

    static func map(_ result: EstimateResult, schaetzungsID: String, projektID: String, maxEvidences: Int) -> KostenSchaetzung {
        let mitte = double(result.totalBand.expected)
        let kostenboden = double(result.bottomUpCost?.total ?? 0)
        let topEvidences = result.evidence.prefix(maxEvidences).map { evidence in
            PriceEvidence(
                lieferant: evidence.supplier,
                dokument: evidence.sourceFile,
                page: evidence.page,
                originalZitat: evidence.quote,
                nettoPreis: double(evidence.netPrice)
            )
        }
        return KostenSchaetzung(
            schaetzungsID: schaetzungsID,
            projektID: projektID,
            minNetto: double(result.totalBand.low),
            maxNetto: double(result.totalBand.high),
            mitteNetto: mitte,
            confidence: result.confidence,
            evidenceCount: result.evidence.count,
            kostenboden: kostenboden,
            kostenbodenRatio: mitte > 0 ? kostenboden / mitte : 0,
            topEvidences: Array(topEvidences)
        )
    }

    static func mapKorpus(_ e: KorpusBandEstimate, schaetzungsID: String, projektID: String,
                          groessenHinweis: String?, openFields: [String] = []) -> KostenSchaetzung {
        var hinweise: [String] = []
        if let g = groessenHinweis { hinweise.append(g) }
        hinweise.append(contentsOf: e.assumptions)
        hinweise.append(contentsOf: e.excludes.map { "Nicht enthalten: \($0)" })
        if openFields.isEmpty == false {
            hinweise.append("Ohne Angabe geschätzt: \(openFields.joined(separator: ", ")) — eine Rückfrage dazu verengt die Spanne spürbar.")
        }

        var lines: [EstimateBreakdownLine] = [
            EstimateBreakdownLine(label: "Möbel ohne Montage (Tischler-EK)",
                         amountNet: double(e.moebelOhneMontage), kind: .estimated),
            EstimateBreakdownLine(label: "Montage und Anfahrt",
                         amountNet: double(e.montageAnteil), kind: .estimated)
        ]
        lines.append(contentsOf: e.excludes.map { exclude in
            let name = exclude.prefix { $0 != "(" }.trimmingCharacters(in: .whitespaces)
            return EstimateBreakdownLine(label: name.isEmpty ? exclude : name,
                                amountNet: nil, kind: .open)
        })

        return KostenSchaetzung(
            schaetzungsID: schaetzungsID,
            projektID: projektID,
            minNetto: double(e.band.low),
            maxNetto: double(e.band.high),
            mitteNetto: double(e.band.expected),
            confidence: Self.korpusKonfidenz,
            evidenceCount: 0,
            kostenboden: 0,
            kostenbodenRatio: 0,
            topEvidences: [],
            modellLabel: "Korpus-BOM-Modell",
            hints: hinweise,
            lines: lines,
            excludes: e.excludes)
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
