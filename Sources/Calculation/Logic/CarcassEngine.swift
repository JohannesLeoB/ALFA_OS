import Foundation

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
