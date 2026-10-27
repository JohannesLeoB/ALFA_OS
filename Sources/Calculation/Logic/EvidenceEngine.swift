import Foundation

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
