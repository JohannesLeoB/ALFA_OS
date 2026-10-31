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

struct ComponentResolveEngine: Sendable {
    func resolve(_ request: EstimateInput) -> [ComponentRequirement] {
        var components: [EstimateComponent] = []
        for component in request.components {
            var adjusted = component
            if adjusted.type == .baseCabinetRun && adjusted.quantity <= 1 && adjusted.unit == "lfm" {
                adjusted.unit = "piece"
                adjusted.componentClass = .baseUnit
            }
            components.append(adjusted)

            if component.drawerCount > 0 {
                let materials = component.materials.filter { $0 == "eiche" || $0 == "legrabox" }
                components.append(EstimateComponent(
                    type: .drawerAddon,
                    quantity: Double(component.drawerCount),
                    unit: "piece",
                    drawerCount: component.drawerCount,
                    materials: materials,
                    scopeNotes: [Notice("calc.note.drawerFromText")],
                    componentClass: .baseUnit
                ))
            }
        }

        let needsLogisticsLine = request.scope.includesDelivery || request.scope.includesInstallation || components.filter { $0.componentClass != .baseUnit }.count >= 2
        if needsLogisticsLine && !components.contains(where: { $0.componentClass == .logistics }) {
            components.append(EstimateComponent(
                type: .delivery,
                quantity: 1,
                unit: "scope",
                materials: [],
                scopeNotes: [Notice("calc.note.logisticsSeparate")],
                componentClass: .logistics
            ))
        }

        return components.map { requirement(for: $0, request: request) }
    }

    private func requirement(for component: EstimateComponent, request: EstimateInput) -> ComponentRequirement {
        func make(allowed: Set<ComponentClass>, forbidden: Set<ComponentClass>, minEvidence: Int, maxScale: Double) -> ComponentRequirement {
            ComponentRequirement(component: component, allowedComponentClasses: allowed, forbiddenComponentClasses: forbidden, minEvidenceCount: minEvidence, maxScaleFactor: maxScale)
        }
        let isAtomic = component.componentClass == .baseUnit || component.type == .drawerAddon || component.unit == "piece"
        if isAtomic {
            return make(allowed: [.baseUnit], forbidden: [.aggregateKitchen, .island, .tallCabinetBlock, .worktopSurface, .logistics, .alternative, .unknownReview], minEvidence: 1, maxScale: 1.4)
        }
        switch component.componentClass {
        case .kitchenRun:
            return make(allowed: request.components.count >= 3 ? [.kitchenRun, .aggregateKitchen] : [.kitchenRun], forbidden: [.baseUnit, .island, .tallCabinetBlock, .worktopSurface, .alternative, .unknownReview], minEvidence: 2, maxScale: 1.8)
        case .island:
            return make(allowed: [.island], forbidden: [.aggregateKitchen, .kitchenRun, .tallCabinetBlock, .worktopSurface, .alternative, .unknownReview], minEvidence: 2, maxScale: 1.8)
        case .tallCabinetBlock:
            return make(allowed: [.tallCabinetBlock], forbidden: [.aggregateKitchen, .kitchenRun, .island, .worktopSurface, .alternative, .unknownReview], minEvidence: 1, maxScale: 1.6)
        case .worktopSurface:
            return make(allowed: [.worktopSurface], forbidden: [.aggregateKitchen, .kitchenRun, .island, .alternative, .unknownReview], minEvidence: 2, maxScale: 2.0)
        case .logistics:
            return make(allowed: [.logistics], forbidden: [.aggregateKitchen, .worktopSurface, .alternative, .unknownReview], minEvidence: 1, maxScale: 1.5)
        case .aggregateKitchen:
            return make(allowed: [.kitchenRun, .island, .tallCabinetBlock, .aggregateKitchen], forbidden: [.alternative, .unknownReview], minEvidence: 3, maxScale: 1.4)
        default:
            return make(allowed: [component.componentClass], forbidden: [.alternative, .unknownReview], minEvidence: 1, maxScale: 1.5)
        }
    }
}

struct CarcassEngine: Sendable {
    let params: CarcassParameters

    func estimate(_ spec: CarcassSpec) -> CarcassEstimate {
        let fix = params.fixedBase

        var travel = Decimal(0)
        if let km = spec.distanceKm, km > params.travelFreeKm {
            travel = Decimal(finite: km - params.travelFreeKm) * params.travelPerKm
        }

        let multiplier = params.frontMultiplier(for: spec.frontExecution)
        let variable = params.variablePerCarcass * Decimal(finite: Double(spec.carcassCount)) * Decimal(finite: multiplier)

        let drawers = params.drawerLegraboxPrice * Decimal(finite: Double(spec.drawersLegrabox))
            + params.drawerSolidPrice * Decimal(finite: Double(spec.drawersSolid))

        let workshopFactor = params.workshopFactor(for: spec.workshop)
        let expected = (fix + variable + drawers) * Decimal(finite: workshopFactor) + travel
        let (lo, hi) = spec.frontExecution.isThinPrior
            ? (params.bandLowThin, params.bandHighThin) : (params.bandLow, params.bandHigh)
        let band = PriceBand(low: expected * Decimal(finite: lo), expected: expected, high: expected * Decimal(finite: hi), currency: "EUR")

        let hourlyRate = spec.installationHourlyRate.map { Decimal(finite: $0) } ?? params.installationHourlyRate
        let installationShare = Decimal(finite: Double(spec.carcassCount)) * Decimal(finite: params.installationHoursPerCarcass) * hourlyRate + travel
        let withoutInstallation = max(Decimal(0), expected - installationShare)

        var assumptions: [Notice] = [
            Notice("calc.carcass.calibration"),
            Notice("calc.carcass.fixedBase", [Notice.amount(fix)]),
            Notice("calc.carcass.variable", [Notice.amount(params.variablePerCarcass), String(spec.carcassCount), Notice.fixed(multiplier, digits: 2), spec.frontExecution.localizationKey]),
            Notice("calc.carcass.allIn", [spec.installationBasis.rawValue]),
        ]
        if spec.drawersLegrabox + spec.drawersSolid > 0 {
            assumptions.append(Notice("calc.carcass.drawers", [String(spec.drawersLegrabox), Notice.amount(params.drawerLegraboxPrice), String(spec.drawersSolid), Notice.amount(params.drawerSolidPrice)]))
        }
        if travel > 0 {
            assumptions.append(Notice("calc.carcass.travel", [Notice.amount(travel), String(Int(spec.distanceKm ?? 0)), String(Int(params.travelFreeKm)), Notice.amount(params.travelPerKm)]))
        }
        if spec.frontExecution.isThinPrior {
            assumptions.append(Notice("calc.carcass.thinPrior", [spec.frontExecution.localizationKey]))
        }
        if workshopFactor != 1.0 {
            assumptions.append(Notice("calc.carcass.workshopFactor", [Notice.fixed(workshopFactor, digits: 2), spec.workshop ?? "?"]))
        } else if spec.workshop == nil {
            assumptions.append(Notice("calc.carcass.workshopUnknown"))
        }
        assumptions.append(Notice("calc.carcass.installationShare", [Notice.amount(installationShare), String(spec.carcassCount), Notice.fixed(params.installationHoursPerCarcass, digits: 1), Notice.amount(hourlyRate), Notice.amount(withoutInstallation)]))

        var snapshot: [String: Double] = [
            "fixkosten_sockel": fix.double,
            "variabel_pro_korpus": params.variablePerCarcass.double,
            "front_faktor_\(spec.frontExecution.rawValue)": multiplier,
            "montage_stunden_pro_korpus": params.installationHoursPerCarcass,
            "montage_stundensatz_default": hourlyRate.double,
        ]
        if spec.drawersLegrabox > 0 { snapshot["schub_legrabox_eur"] = params.drawerLegraboxPrice.double }
        if spec.drawersSolid > 0 { snapshot["schub_holz_eur"] = params.drawerSolidPrice.double }
        if travel > 0 { snapshot["anfahrt_pro_km"] = params.travelPerKm.double }
        if let workshop = spec.workshop, workshop.isEmpty == false {
            let key = CarcassCalibrationTarget.workshopFactor(normalizedWorkshop(workshop)).key
            snapshot[key] = workshopFactor
        }

        return CarcassEstimate(
            band: band, fixedCost: fix, travel: travel, variable: variable, drawers: drawers,
            installationShare: installationShare, furnitureWithoutInstallation: withoutInstallation,
            carcassCount: spec.carcassCount, frontExecution: spec.frontExecution,
            assumptions: assumptions, excludes: Exclusion.allCases, parameterSnapshot: snapshot)
    }

    func spec(components: [EstimateComponent], scope: ScopeFlags, distanceKm: Double?) -> CarcassSpec {
        var carcasses = 0.0
        var drawers = 0
        let materials = components.reduce(into: Set<String>()) { $0.formUnion($1.materials) }
        for component in components {
            switch component.componentClass {
            case .kitchenRun: carcasses += (component.widthM ?? component.quantity) / 0.6
            case .baseUnit: carcasses += max(1.0, (component.widthM ?? 0.6) / 0.6)
            case .tallCabinetBlock: carcasses += max(1.0, (component.widthM ?? component.quantity) / 0.6)
            case .island: carcasses += ((component.widthM ?? component.quantity) / 0.6) * 1.6
            case .aggregateKitchen:
                if let width = component.widthM { carcasses += width / 0.6 }
                else if component.unit == "lfm" || component.unit == "m" { carcasses += component.quantity / 0.6 }
            default: break
            }
            drawers += component.drawerCount
        }
        let execution = FrontExecution.infer(from: materials)

        let solidDrawers = FrontExecution.infer(from: materials) == .veneer
            || materials.contains(where: { ["massiv", "eiche", "nussbaum"].contains($0.lowercased()) }) ? drawers : 0
        let legraboxDrawers = drawers - solidDrawers
        let installationNote = Notice("calc.scope.installationIncluded")
        let basis: InstallationBasis = scope.includesInstallation ? .included : (scope.notes.contains(installationNote) ? .separate : .unknown)
        return CarcassSpec(carcassCount: Int(carcasses.rounded()), frontExecution: execution,
                           drawersLegrabox: legraboxDrawers, drawersSolid: solidDrawers,
                           distanceKm: distanceKm, installationBasis: basis)
    }

    private func normalizedWorkshop(_ name: String) -> String {
        let tokens = name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        for token in tokens where params.workshopFactors[token] != nil { return token }
        return tokens.first ?? name.lowercased()
    }
}
