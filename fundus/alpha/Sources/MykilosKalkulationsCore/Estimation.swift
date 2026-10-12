import Foundation

public protocol PriceAnchorProviding {
    func activeAnchors() throws -> [CandidateReleaseDecision]
}

public final class EvidenceBasedEstimator {
    private let provider: PriceAnchorProviding
    private let calibrationProvider: CalibrationFactorProviding?
    private let resolver: ComponentResolver

    public init(provider: PriceAnchorProviding, calibrationProvider: CalibrationFactorProviding? = nil, resolver: ComponentResolver = ComponentResolver()) {
        self.provider = provider
        self.calibrationProvider = calibrationProvider
        self.resolver = resolver
    }

    public func estimate(_ request: EstimateRequest) throws -> EstimateResult {
        let anchors = try provider.activeAnchors()
        let requirements = resolver.resolve(request)
        var lines: [EstimateLine] = []
        var allEvidence: [EvidenceCase] = []
        var dataGaps: [String] = []

        var missingComponents = 0

        for requirement in requirements {
            let candidates = selectCandidates(for: requirement, anchors: anchors)
            if candidates.count < requirement.minEvidenceCount {
                dataGaps.append("Nur \(candidates.count) von \(requirement.minEvidenceCount) benötigten Preisankern für \(requirement.component.type.displayName).")
            }
            guard !candidates.isEmpty else { missingComponents += 1; continue }

            let chosen = Array(candidates.prefix(5))
            let evidence = chosen.map { evidenceCase(from: $0, requirement: requirement) }
            let expected = price(requirement: requirement, candidates: chosen)
            let spread = spreadFactor(for: requirement, evidenceCount: chosen.count, candidates: chosen)
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
                rationale: rationale(for: requirement, evidenceCount: evidence.count)
            ))
            allEvidence.append(contentsOf: evidence)
        }

        let stochasticComponents: [StochasticAggregator.Component] = lines.map { line in
            let expectedD = NSDecimalNumber(decimal: line.priceBand.expected).doubleValue
            let highD = NSDecimalNumber(decimal: line.priceBand.high).doubleValue
            let spread = expectedD > 0 ? max(0, (highD - expectedD) / expectedD) : 0
            return .init(median: expectedD, sigma: StochasticAggregator.sigma(fromRelativeSpread: spread))
        }
        let aggregate = StochasticAggregator.aggregate(components: stochasticComponents)
        let expected = Decimal(aggregate.mean.rounded())
        let baseTotal = PriceBand(
            low: Decimal(aggregate.low.rounded()),
            expected: expected,
            high: Decimal(aggregate.high.rounded()),
            currency: "EUR"
        )
        let implausible = requirements.filter { $0.component.scopeNotes.contains("size_implausible") }
        for requirement in implausible {
            dataGaps.append("Unrealistische Größe bei \(requirement.component.type.displayName) — Schätzung gekappt, bitte prüfen.")
        }

        let evidenceConfidence = allEvidence.isEmpty ? 0.2 : allEvidence.map(\.confidence).reduce(0, +) / Double(allEvidence.count)
        let evidenceScore = max(0.1, min(0.95, evidenceConfidence - Double(dataGaps.count) * 0.04))
        var confidence = StochasticAggregator.confidence(evidenceScore: evidenceScore, relativeWidth: aggregate.relativeWidth)

        if !implausible.isEmpty { confidence = min(confidence, 0.35) }

        if missingComponents > 0 {
            confidence = max(0.1, confidence * pow(0.6, Double(missingComponents)))
            dataGaps.append("\(missingComponents) Komponente(n) ohne Beleg — Gesamtschätzung unvollständig (wahrscheinlich zu niedrig).")
        }
        let baseLaborValue = expected * Decimal(string: "0.42")!
        let excluded = [
            "Atomare Anfragen verwenden keine Pantry/Gesamtküche/Einbauschrank/Hochschrankblock/Insel-Aggregate.",
            "Übertrag",
            "Nettobetrag/Gesamtbetrag",
            "MwSt/Bruttobetrag",
            "Alternative/Mehrpreis nicht im Hauptschätzer"
        ]
        let scopeNotes = request.scope.notes.isEmpty ? ["Geräte, Arbeitsplatte, Lieferung und Montage werden getrennt bewertet oder ausdrücklich ausgeschlossen."] : request.scope.notes
        let calibration = try applyActiveCalibrations(baseTotal: baseTotal, lines: lines)
        let laborValue = calibration.total.expected * Decimal(string: "0.42")!

        let bottomUp = BottomUpCostEngine().estimate(components: requirements.map(\.component))
        if bottomUp.total > 0 {
            let floorEUR = NSDecimalNumber(decimal: bottomUp.total).doubleValue
            let ratio = NSDecimalNumber(decimal: calibration.total.expected).doubleValue / floorEUR
            if ratio < 0.95 {
                dataGaps.append("Schätzung liegt unter dem Material+Lohn-Bodenpreis (\(Int(floorEUR.rounded())) €) — möglicherweise zu niedrig; Umfang prüfen.")
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

    private func applyActiveCalibrations(baseTotal: PriceBand, lines: [EstimateLine]) throws -> (total: PriceBand, applications: [AppliedCalibrationFactor]) {
        guard let calibrationProvider else { return (baseTotal, []) }
        let factors = try calibrationProvider.activeCalibrationFactors().filter { $0.status == .active }
        guard !factors.isEmpty, baseTotal.expected > 0 else { return (baseTotal, []) }

        var finalExpected = baseTotal.expected
        var applications: [AppliedCalibrationFactor] = []
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
            applications.append(AppliedCalibrationFactor(
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

    private func selectCandidates(for requirement: ComponentRequirement, anchors: [CandidateReleaseDecision]) -> [CandidateReleaseDecision] {
        anchors
            .filter { !$0.isSuperseded && ($0.isReleaseReady || $0.sourceKind == .ruleBasedAnchor) }
            .filter { !requirement.forbiddenComponentClasses.contains($0.componentClass) }
            .filter { requirement.allowedComponentClasses.contains($0.componentClass) }
            .filter { anchor in
                if anchor.componentClass == .alternative { return false }
                let carryforwardStatus = anchor.carryforwardRuleStatus.lowercased()
                let carryforwardSafe = carryforwardStatus.hasPrefix("double_ep_gp") || carryforwardStatus.contains("double_e_g_price")
                if CarryforwardRule.isForbiddenContext(anchor.evidenceQuote) && !carryforwardSafe {
                    return false
                }
                if !densityCompatible(anchor: anchor, requirement: requirement) { return false }
                return scopeCompatible(anchor: anchor, requirement: requirement)
            }
            .map { anchor in (anchor: anchor, score: score(anchor: anchor, requirement: requirement)) }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.anchor.decisionScore > rhs.anchor.decisionScore }
                return lhs.score > rhs.score
            }
            .map(\.anchor)
    }

    private func densityCompatible(anchor: CandidateReleaseDecision, requirement: ComponentRequirement) -> Bool {
        let component = requirement.component
        guard component.componentClass == .kitchenRun || component.componentClass == .aggregateKitchen else { return true }
        let queryDensity = KitchenEquipmentDensity.classifyQuery(
            drawerCount: component.drawerCount,
            lengthM: component.unit == "lfm" ? component.quantity : component.widthM
        )
        guard queryDensity != .unknown else { return true }
        return !queryDensity.isHardIncompatible(with: anchor.equipmentDensity)
    }

    private func scopeCompatible(anchor: CandidateReleaseDecision, requirement: ComponentRequirement) -> Bool {
        if requirement.component.type == .drawerAddon {
            let lower = [anchor.candidateID, anchor.component, anchor.title].joined(separator: " ").lowercased()
            if lower.contains("unterschrank") || lower.contains("60cm") { return false }
            return anchor.sourceKind == .ruleBasedAnchor && (lower.contains("drawer") || lower.contains("schubkasten") || lower.contains("schubkästen") || lower.contains("legrabox"))
        }
        if requirement.component.componentClass == .baseUnit {
            let lower = [anchor.component, anchor.title, anchor.evidenceQuote].joined(separator: " ").lowercased()
            if requirement.component.unit == "piece" {
                if anchor.sourceKind != .ruleBasedAnchor && anchor.ruleNotes != "component_price_atom" { return false }
                if anchor.ruleNotes == "component_price_atom", anchor.priceNetGuess > Decimal(1800) { return false }
            }
            if requirement.component.type != .drawerAddon && (lower.contains("schub") || lower.contains("drawer") || lower.contains("legrabox")) {
                return false
            }
            if lower.contains("pantry") || lower.contains("hochschrank") || lower.contains("insel") || lower.contains("einbauschrank") || lower.contains("gesamtküche") || lower.contains("gesamt küche") {
                return anchor.sourceKind == .ruleBasedAnchor && anchor.candidateID.hasPrefix("BASE_")
            }
        }
        if requirement.component.componentClass == .worktopSurface,
           requirement.component.unit == "m2",
           anchor.ruleNotes != "component_price_atom" {
            return false
        }
        if requirement.component.componentClass == .logistics,
           anchor.priceNetGuess > Decimal(3500) {
            return false
        }
        return true
    }

    private func score(anchor: CandidateReleaseDecision, requirement: ComponentRequirement) -> Double {
        let component = requirement.component
        var score = anchor.decisionScore + anchor.confidence
        let lower = [anchor.component, anchor.title, anchor.evidenceQuote, anchor.ruleNotes].joined(separator: " ").lowercased()
        if anchor.ruleNotes == "component_price_atom" { score += 1.4 }
        if anchor.sourceKind == .ruleBasedAnchor { score += 0.35 }
        for material in component.materials where lower.contains(material.lowercased()) {
            score += 0.28
        }
        if component.type == .drawerAddon {
            if lower.contains("schub") || lower.contains("drawer") || lower.contains("legrabox") { score += 1.2 }
            if component.materials.contains("eiche") && lower.contains("eiche") { score += 0.6 }
        }
        if component.componentClass == .baseUnit && lower.contains("60cm") { score += 1.0 }
        if component.componentClass == .kitchenRun && lower.contains("linoleum") { score += 0.25 }

        if component.componentClass == .kitchenRun || component.componentClass == .aggregateKitchen {
            let queryDensity = KitchenEquipmentDensity.classifyQuery(
                drawerCount: component.drawerCount,
                lengthM: component.unit == "lfm" ? component.quantity : component.widthM
            )
            if let queryLevel = queryDensity.level, let anchorLevel = anchor.equipmentDensity.level {
                if queryLevel == anchorLevel { score += 0.6 } else if abs(queryLevel - anchorLevel) == 1 { score += 0.2 }
            }
        }
        if component.materials.contains("edelstahl") && lower.contains("edelstahl") { score += 0.7 }
        if lower.contains("alternative") || lower.contains("mehrpreis") { score -= 1.5 }
        return score
    }

    private func price(requirement: ComponentRequirement, candidates: [CandidateReleaseDecision]) -> Decimal {
        guard !candidates.isEmpty else { return 0 }
        if requirement.component.type == .drawerAddon {
            let additive = candidates
                .filter { $0.sourceKind == .ruleBasedAnchor }
                .map { adjustedPrice(candidate: $0, requirement: requirement) }
                .reduce(Decimal(0), +)
            if additive > 0 { return additive }
        }
        let weighted = candidates.reduce((sum: Decimal(0), weights: Decimal(0))) { partial, candidate in
            let unitAdjusted = adjustedPrice(candidate: candidate, requirement: requirement)
            let weight = Decimal(max(0.1, candidate.decisionScore + (candidate.sourceKind == .ruleBasedAnchor ? 0.2 : 0)))
            return (partial.sum + unitAdjusted * weight, partial.weights + weight)
        }
        return weighted.weights == 0 ? 0 : weighted.sum / weighted.weights
    }

    private func adjustedPrice(candidate: CandidateReleaseDecision, requirement: ComponentRequirement) -> Decimal {
        let component = requirement.component
        let base = candidate.ruleSafePriceNet ?? candidate.priceNetGuess

        if candidate.sourceKind == .ruleBasedAnchor {
            switch candidate.candidateID {
            case "BASE_DRAWER_LEGRABOX":
                return component.materials.contains("legrabox") ? base * Decimal(component.quantity) : 0
            case "BASE_DRAWER_OAK_UPCHARGE":
                return component.materials.contains("eiche") ? base * Decimal(component.quantity) : 0
            case "BASE_LINOL_FRONT_PER_LFM":
                return component.materials.contains("linoleum") ? base * Decimal(component.quantity) : 0
            case "BASE_STAINLESS_FRONT_PER_M2":
                let area = Decimal((component.widthM ?? component.quantity) * (component.depthM ?? 1.0))
                return component.materials.contains("edelstahl") ? base * max(Decimal(1), area) : 0
            default:
                return base * (component.unit == "piece" ? Decimal(component.quantity) : Decimal(1))
            }
        }

        var price = base
        if candidate.ruleNotes == "component_price_atom" {
            let lower = [candidate.component, candidate.title, candidate.evidenceQuote].joined(separator: " ").lowercased()
            if lower.contains("per_lfm") {
                let length = component.unit == "piece" ? (component.widthM ?? 0.6) : component.quantity
                let scaled = base * Decimal(length)
                if component.componentClass == .baseUnit && component.unit == "piece" {
                    return max(scaled, Decimal(820))
                }
                return scaled
            }
            if lower.contains("per_m2") {
                var adjusted = base * Decimal(component.quantity)
                if component.materials.contains("stein") || component.materials.contains("naturstein") {
                    adjusted *= Decimal(string: "0.44")!
                }
                return adjusted
            }
            return base * (component.unit == "piece" ? Decimal(component.quantity) : Decimal(1))
        }
        if let sourceLength = candidate.lengthM, sourceLength > 0, component.quantity > 0, component.unit == "lfm" {
            let ratio = min(requirement.maxScaleFactor, max(0.35, component.quantity / sourceLength))
            price *= Decimal(ratio)
        }
        if component.materials.contains("edelstahl") && !candidate.materialsText.lowercased().contains("edelstahl") {
            price *= Decimal(string: "1.18")!
        }
        if component.materials.contains("fenix") && !candidate.materialsText.lowercased().contains("fenix") {
            price *= Decimal(string: "1.12")!
        }
        if component.materials.contains("eiche") && !candidate.materialsText.lowercased().contains("eiche") {
            price *= Decimal(string: "1.08")!
        }
        return price
    }

    private func spreadFactor(for requirement: ComponentRequirement, evidenceCount: Int,
                              candidates: [CandidateReleaseDecision] = []) -> Decimal {
        if requirement.component.scopeNotes.contains("size_estimated")
            || requirement.component.scopeNotes.contains("size_implausible") { return Decimal(string: "0.40")! }

        if requirement.component.type != .drawerAddon {
            let unit = candidates
                .map { adjustedPrice(candidate: $0, requirement: requirement) }
                .filter { $0 > 0 }
                .map { NSDecimalNumber(decimal: $0).doubleValue }
                .sorted()
            if unit.count >= 2 {
                let median = unit[unit.count / 2]
                if median > 0 {
                    let relHalfWidth = (unit.last! - unit.first!) / (2 * median)
                    let floor = requirement.component.componentClass == .baseUnit ? 0.12 : 0.10
                    return Decimal(min(0.45, max(floor, relHalfWidth)))
                }
            }
        }

        if requirement.component.componentClass == .baseUnit { return Decimal(string: "0.14")! }
        if evidenceCount >= 4 { return Decimal(string: "0.12")! }
        if evidenceCount >= 2 { return Decimal(string: "0.16")! }
        return Decimal(string: "0.22")!
    }

    private func rationale(for requirement: ComponentRequirement, evidenceCount: Int) -> String {
        let allowed = requirement.allowedComponentClasses.map(\.rawValue).sorted().joined(separator: ", ")
        let forbidden = requirement.forbiddenComponentClasses.map(\.rawValue).sorted().joined(separator: ", ")
        return "Eligible: \(allowed). Ausgeschlossen: \(forbidden). Evidence: \(evidenceCount)."
    }

    private func evidenceCase(from anchor: CandidateReleaseDecision, requirement: ComponentRequirement) -> EvidenceCase {
        let unitPrice: Decimal?
        if let length = anchor.lengthM, length > 0 {
            unitPrice = anchor.priceNetGuess / Decimal(length)
        } else {
            unitPrice = anchor.sourceKind == .ruleBasedAnchor ? anchor.priceNetGuess : nil
        }
        return EvidenceCase(
            priceAnchorID: anchor.candidateID,
            sourceFile: anchor.sourceFile,
            page: anchor.page,
            supplier: anchor.supplier,
            project: anchor.project,
            component: anchor.component,
            scope: "\(anchor.componentClass.displayName) · \(anchor.sourceKind.rawValue)",
            confidence: anchor.confidence,
            netPrice: anchor.ruleSafePriceNet ?? anchor.priceNetGuess,
            unitPrice: unitPrice,
            quote: anchor.evidenceQuote,
            risksExcluded: ["Keine produktive Nutzung von Summen, MwSt.-Zeilen, Überträgen oder verbotenen Komponentenklassen."]
        )
    }
}

public typealias ComponentEstimator = EvidenceBasedEstimator

extension CandidateReleaseDecision {
    var materialsText: String { [title, evidenceQuote].joined(separator: " ") }
    var lengthM: Double? {
        let pattern = #"([0-9]+(?:[,.][0-9]+)?)\s*(?:m|lfm)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let text = [title, evidenceQuote].joined(separator: " ")
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, range: nsRange),
              let range = Range(result.range(at: 1), in: text) else { return nil }
        return GermanNumberParser.double(String(text[range]))
    }
}
