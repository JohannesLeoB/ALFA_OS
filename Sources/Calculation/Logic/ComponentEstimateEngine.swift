import Foundation

struct ComponentEstimateEngine: Sendable {
    func selectCandidates(for requirement: ComponentRequirement, anchors: [CandidateReleaseDecision]) -> [CandidateReleaseDecision] {
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
        let queryDensity = EquipmentDensity.classifyQuery(
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
            let queryDensity = EquipmentDensity.classifyQuery(
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

    func price(requirement: ComponentRequirement, candidates: [CandidateReleaseDecision]) -> Decimal {
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

    func spreadFactor(for requirement: ComponentRequirement, evidenceCount: Int, candidates: [CandidateReleaseDecision]) -> Decimal {
        if requirement.component.scopeNotes.contains(.sizeEstimated)
            || requirement.component.scopeNotes.contains(.sizeImplausible) { return Decimal(string: "0.40")! }

        if requirement.component.type != .drawerAddon {
            let unit = candidates
                .map { adjustedPrice(candidate: $0, requirement: requirement) }
                .filter { $0 > 0 }
                .map(\.double)
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

    func rationale(for requirement: ComponentRequirement, evidenceCount: Int) -> Notice {
        let allowed = requirement.allowedComponentClasses.map(\.rawValue).sorted().joined(separator: ", ")
        let forbidden = requirement.forbiddenComponentClasses.map(\.rawValue).sorted().joined(separator: ", ")
        return Notice("calc.rationale", [allowed, forbidden, String(evidenceCount)])
    }

    func evidenceCase(from anchor: CandidateReleaseDecision) -> EvidenceCase {
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
            scope: "\(anchor.componentClass.rawValue) · \(anchor.sourceKind.rawValue)",
            confidence: anchor.confidence,
            netPrice: anchor.ruleSafePriceNet ?? anchor.priceNetGuess,
            unitPrice: unitPrice,
            quote: anchor.evidenceQuote,
            risksExcluded: [Notice("calc.risk.noSums")]
        )
    }
}

enum CarryforwardRule {
    static let forbiddenContexts = ["übertrag", "uebertrag", "nettobetrag", "gesamtbetrag", "mehrwertsteuer", "mwst", "bruttobetrag", "endbetrag", "zwischensumme", "summe"]

    static func isForbiddenContext(_ text: String) -> Bool {
        let lower = text.lowercased()
        return forbiddenContexts.contains { lower.contains($0) }
    }
}
