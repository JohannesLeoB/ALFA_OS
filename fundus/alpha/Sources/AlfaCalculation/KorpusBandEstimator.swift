import Foundation

@inline(__always) private func decK(_ value: Double) -> Decimal {
    value.isFinite ? Decimal(value) : Decimal(0)
}

public enum FrontExecution: String, Codable, CaseIterable, Sendable {
    case melamin, linoleum, furnier, lack, edelstahl, massivholz, glas, unbekannt

    public var variableMultiplier: Double {
        switch self {
        case .melamin:    0.85   
        case .linoleum:   1.00   
        case .furnier:    1.05   
        case .glas:       1.25   
        case .massivholz: 1.30   
        case .lack:       1.05   

        case .edelstahl:  1.45   
        case .unbekannt:  1.00
        }
    }

    public var isThinPrior: Bool {
        switch self {
        case .edelstahl, .lack, .glas, .massivholz: true
        default: false
        }
    }

    public var label: String {
        switch self {
        case .melamin: "Dekorspan/Melamin"
        case .linoleum: "Linoleum auf MDF/Träger"
        case .furnier: "Furnier"
        case .lack: "Lack"
        case .edelstahl: "Edelstahl"
        case .massivholz: "Massivholz"
        case .glas: "Glas"
        case .unbekannt: "unbekannt"
        }
    }

    public static func infer(from materials: Set<String>) -> FrontExecution {
        let m = Set(materials.map { $0.lowercased() })
        func any(_ needles: String...) -> Bool { needles.contains { n in m.contains { $0.contains(n) } } }
        if any("edelstahl", "stainless", "v2a", "1.4301") { return .edelstahl }
        if any("linoleum", "valchromat", "forbo", "forescolor", "fenix") { return .linoleum }
        if any("lack", "hochglanz", "lackiert") { return .lack }
        if any("furnier", "eiche", "nussbaum", "esche", "ahorn", "walnuss") { return .furnier }
        if any("massivholz", "massiv") { return .massivholz }
        if any("glas", "riffelglas", "bronzeglas") { return .glas }
        if any("dekorspan", "melamin", "egger", "spanplatte", "pfleiderer", "mdf") { return .melamin }
        return .unbekannt
    }
}

public enum MontageBasis: String, Codable, Sendable {
    case inklusive   
    case separat     
    case unbekannt
}

public struct KorpusKitchenSpec: Codable, Equatable, Sendable {
    public var korpusCount: Int
    public var frontExecution: FrontExecution

    public var drawersLegrabox: Int

    public var drawersHolz: Int

    public var distanceKm: Double?

    public var montageBasisHinweis: MontageBasis

    public var montageStundensatz: Double?

    public var werkstatt: String?

    public init(korpusCount: Int, frontExecution: FrontExecution, drawersLegrabox: Int = 0,
                drawersHolz: Int = 0, distanceKm: Double? = nil, montageBasisHinweis: MontageBasis = .inklusive,
                montageStundensatz: Double? = nil, werkstatt: String? = nil) {
        self.korpusCount = max(0, korpusCount)
        self.frontExecution = frontExecution
        self.drawersLegrabox = max(0, drawersLegrabox)
        self.drawersHolz = max(0, drawersHolz)
        self.distanceKm = distanceKm
        self.montageBasisHinweis = montageBasisHinweis
        self.montageStundensatz = montageStundensatz
        self.werkstatt = werkstatt
    }
}

public struct KorpusBandEstimate: Codable, Equatable, Sendable {
    public let band: PriceBand
    public let fixkosten: Decimal
    public let anfahrt: Decimal
    public let variabel: Decimal
    public let schubkaesten: Decimal

    public let montageAnteil: Decimal

    public let moebelOhneMontage: Decimal
    public let korpusCount: Int
    public let frontExecution: FrontExecution
    public let assumptions: [String]

    public let excludes: [String]

    public let parameterSnapshot: [String: Double]
}

public struct KorpusModelParameters: Codable, Sendable {
    public var fixkostenSockel: Decimal
    public var variabelProKorpus: Decimal
    public var frontMultipliers: [String: Double]          
    public var schubLegraboxEUR: Decimal
    public var schubHolzEUR: Decimal
    public var anfahrtProKmEUR: Decimal
    public var anfahrtFreiKm: Double
    public var montageStundenProKorpus: Double
    public var montageStundensatzDefaultEUR: Decimal
    public var bandLow: Double
    public var bandHigh: Double
    public var bandLowThin: Double
    public var bandHighThin: Double

    public var werkstattFaktoren: [String: Double]

    public init(fixkostenSockel: Decimal, variabelProKorpus: Decimal, frontMultipliers: [String: Double],
                schubLegraboxEUR: Decimal, schubHolzEUR: Decimal, anfahrtProKmEUR: Decimal, anfahrtFreiKm: Double,
                montageStundenProKorpus: Double, montageStundensatzDefaultEUR: Decimal,
                bandLow: Double, bandHigh: Double, bandLowThin: Double, bandHighThin: Double,
                werkstattFaktoren: [String: Double] = [:]) {
        self.fixkostenSockel = fixkostenSockel; self.variabelProKorpus = variabelProKorpus
        self.frontMultipliers = frontMultipliers; self.schubLegraboxEUR = schubLegraboxEUR
        self.schubHolzEUR = schubHolzEUR; self.anfahrtProKmEUR = anfahrtProKmEUR; self.anfahrtFreiKm = anfahrtFreiKm
        self.montageStundenProKorpus = montageStundenProKorpus; self.montageStundensatzDefaultEUR = montageStundensatzDefaultEUR
        self.bandLow = bandLow; self.bandHigh = bandHigh; self.bandLowThin = bandLowThin; self.bandHighThin = bandHighThin
        self.werkstattFaktoren = werkstattFaktoren
    }

    public func frontMultiplier(for f: FrontExecution) -> Double { frontMultipliers[f.rawValue] ?? f.variableMultiplier }

    public func werkstattFaktor(for name: String?) -> Double {
        guard let name, name.isEmpty == false else { return 1.0 }
        if let treffer = werkstattFaktoren[String(name.lowercased().filter { $0.isLetter || $0.isNumber })] { return treffer }
        for token in name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            if let treffer = werkstattFaktoren[String(token)] { return treffer }
        }
        return 1.0
    }

    public static func from(parameters p: [String: Double], fallback: KorpusModelParameters = .seed) -> KorpusModelParameters {
        func d(_ k: String, _ fb: Decimal) -> Decimal { p[k].map { Decimal($0) } ?? fb }
        func f(_ k: String, _ fb: Double) -> Double { p[k] ?? fb }
        var fronts = fallback.frontMultipliers
        for fe in FrontExecution.allCases where p["front_faktor_\(fe.rawValue)"] != nil { fronts[fe.rawValue] = p["front_faktor_\(fe.rawValue)"]! }
        var werk = fallback.werkstattFaktoren
        for (k, v) in p where k.hasPrefix("werkstatt_faktor_") { werk[String(k.dropFirst("werkstatt_faktor_".count))] = v }
        return KorpusModelParameters(
            fixkostenSockel: d("fixkosten_sockel", fallback.fixkostenSockel),
            variabelProKorpus: d("variabel_pro_korpus", fallback.variabelProKorpus),
            frontMultipliers: fronts,
            schubLegraboxEUR: d("schub_legrabox_eur", fallback.schubLegraboxEUR),
            schubHolzEUR: d("schub_holz_eur", fallback.schubHolzEUR),
            anfahrtProKmEUR: d("anfahrt_pro_km", fallback.anfahrtProKmEUR),
            anfahrtFreiKm: f("anfahrt_frei_km", fallback.anfahrtFreiKm),
            montageStundenProKorpus: f("montage_stunden_pro_korpus", fallback.montageStundenProKorpus),
            montageStundensatzDefaultEUR: d("montage_stundensatz_default", fallback.montageStundensatzDefaultEUR),
            bandLow: f("band_low", fallback.bandLow), bandHigh: f("band_high", fallback.bandHigh),
            bandLowThin: f("band_low_thin", fallback.bandLowThin), bandHighThin: f("band_high_thin", fallback.bandHighThin),
            werkstattFaktoren: werk)
    }

    public static var seed: KorpusModelParameters { KorpusModelParameters(
        fixkostenSockel: KorpusBandEstimator.fixkostenSockel,
        variabelProKorpus: KorpusBandEstimator.variabelProKorpus,
        frontMultipliers: Dictionary(uniqueKeysWithValues: FrontExecution.allCases.map { ($0.rawValue, $0.variableMultiplier) }),
        schubLegraboxEUR: KorpusBandEstimator.schubLegraboxEUR, schubHolzEUR: KorpusBandEstimator.schubHolzEUR,
        anfahrtProKmEUR: KorpusBandEstimator.anfahrtProKmEUR, anfahrtFreiKm: KorpusBandEstimator.anfahrtFreiKm,
        montageStundenProKorpus: KorpusBandEstimator.montageStundenProKorpus,
        montageStundensatzDefaultEUR: KorpusBandEstimator.montageStundensatzDefaultEUR,
        bandLow: KorpusBandEstimator.bandLow, bandHigh: KorpusBandEstimator.bandHigh,
        bandLowThin: KorpusBandEstimator.bandLowThin, bandHighThin: KorpusBandEstimator.bandHighThin,
        werkstattFaktoren: WorkshopFactors.current) }
}

public struct KorpusBandEstimator {
    public let params: KorpusModelParameters
    public init(params: KorpusModelParameters = .seed) { self.params = params }

    public static let fixkostenSockel: Decimal = 6500

    public static let variabelProKorpus: Decimal = 685

    public static let anfahrtProKmEUR: Decimal = 8
    public static let anfahrtFreiKm: Double = 30

    public static let montageStundenProKorpus: Double = 3.3
    public static let montageStundensatzDefaultEUR: Decimal = 81

    public static let schubLegraboxEUR: Decimal = 70
    public static let schubHolzEUR: Decimal = 132   

    static let bandLow = 0.72, bandHigh = 1.40
    static let bandLowThin = 0.62, bandHighThin = 1.58

    public func estimate(_ spec: KorpusKitchenSpec) -> KorpusBandEstimate {
        let fix = params.fixkostenSockel

        var anfahrt = Decimal(0)
        if let km = spec.distanceKm, km > params.anfahrtFreiKm {
            anfahrt = decK(km - params.anfahrtFreiKm) * params.anfahrtProKmEUR
        }

        let mult = params.frontMultiplier(for: spec.frontExecution)
        let variabel = params.variabelProKorpus * decK(Double(spec.korpusCount)) * decK(mult)

        let schub = params.schubLegraboxEUR * decK(Double(spec.drawersLegrabox))
                  + params.schubHolzEUR * decK(Double(spec.drawersHolz))

        let werkFaktor = params.werkstattFaktor(for: spec.werkstatt)   
        let expected = (fix + variabel + schub) * decK(werkFaktor) + anfahrt
        let (lo, hi) = spec.frontExecution.isThinPrior
            ? (params.bandLowThin, params.bandHighThin) : (params.bandLow, params.bandHigh)
        let band = PriceBand(low: expected * decK(lo), expected: expected, high: expected * decK(hi), currency: "EUR")

        let stundensatz = spec.montageStundensatz.map(decK) ?? params.montageStundensatzDefaultEUR
        let montageAnteil = decK(Double(spec.korpusCount)) * decK(params.montageStundenProKorpus) * stundensatz + anfahrt
        let moebelOhneMontage = max(Decimal(0), expected - montageAnteil)

        var assumptions: [String] = [
            "AFFIN kalibriert auf 20 reale eingehende Angebots-Positionen (Leave-one-out ~19 % Median-Fehler).",
            "Fixkosten-Sockel \(moneyK(fix)) (Planung/Rüsten/Basis-Montage) — NICHT linear, trägt jede Küche voll.",
            "Variabel \(moneyK(params.variabelProKorpus))/Korpus × \(spec.korpusCount) Korpen × Front-Faktor \(String(format: "%.2f", mult)) (\(spec.frontExecution.label)).",
            "Ergebnis all-in = geliefert + montiert. Montage-Basis Hinweis: \(spec.montageBasisHinweis.rawValue)."
        ]
        if spec.drawersLegrabox + spec.drawersHolz > 0 {
            assumptions.append("Schubkästen: \(spec.drawersLegrabox)× Legrabox à \(moneyK(params.schubLegraboxEUR)) + \(spec.drawersHolz)× Holz-massiv à \(moneyK(params.schubHolzEUR)).")
        }
        if anfahrt > 0 {
            assumptions.append("Anfahrt \(moneyK(anfahrt)) (\(Int(spec.distanceKm ?? 0)) km, jenseits \(Int(params.anfahrtFreiKm)) km Nahbereich × \(moneyK(params.anfahrtProKmEUR))/km) — Prior.")
        }
        if spec.frontExecution.isThinPrior {
            assumptions.append("Front-Faktor \(spec.frontExecution.label) ist ein Prior (n=1 in den Daten) → bewusst breiteres Band.")
        }
        if werkFaktor != 1.0 {
            assumptions.append("Werkstatt-Faktor ×\(String(format: "%.2f", werkFaktor)) (\(spec.werkstatt ?? "?")) auf den Möbelanteil — Faktor 1,0 als günstiger Pol.")
        } else if spec.werkstatt == nil {
            assumptions.append("Werkstatt unbekannt → kein Werkstatt-Faktor; Spanne deckt den Werkstatt-Spread (~1,0–1,3×) mit ab.")
        }
        assumptions.append("Montageanteil \(moneyK(montageAnteil)) (\(spec.korpusCount) Korpen × \(String(format: "%.1f", params.montageStundenProKorpus)) h × \(moneyK(stundensatz))/h + Anfahrt) → Küche OHNE Montage ≈ \(moneyK(moebelOhneMontage)).")

        var snapshot: [String: Double] = [
            "fixkosten_sockel": double(fix),
            "variabel_pro_korpus": double(params.variabelProKorpus),
            "front_faktor_\(spec.frontExecution.rawValue)": mult,
            "montage_stunden_pro_korpus": params.montageStundenProKorpus,
            "montage_stundensatz_default": double(stundensatz),
        ]
        if spec.drawersLegrabox > 0 { snapshot["schub_legrabox_eur"] = double(params.schubLegraboxEUR) }
        if spec.drawersHolz > 0 { snapshot["schub_holz_eur"] = double(params.schubHolzEUR) }
        if anfahrt > 0 { snapshot["anfahrt_pro_km"] = double(params.anfahrtProKmEUR) }
        if let werkstatt = spec.werkstatt, werkstatt.isEmpty == false {
            let key = KorpusKalibrierZiel.werkstattFaktor(Self.normalisiereWerkstatt(werkstatt, bekannt: params.werkstattFaktoren)).schaetzmodellSchluessel
            snapshot[key] = werkFaktor
        }

        return KorpusBandEstimate(band: band, fixkosten: fix, anfahrt: anfahrt, variabel: variabel,
                                  schubkaesten: schub, montageAnteil: montageAnteil, moebelOhneMontage: moebelOhneMontage,
                                  korpusCount: spec.korpusCount,
                                  frontExecution: spec.frontExecution, assumptions: assumptions,
                                  excludes: ["Arbeitsplatte (separate Achse: Steinmetz/Stadler-Edelstahl/Tischler, je m²×Material)",
                                             "Geräte (Artikel-DB-Lookup, kein Schätzproblem)",
                                             "mykilOS-Marge (getrennte, projektvariable Ebene)"],
                                  parameterSnapshot: snapshot)
    }

    static func normalisiereWerkstatt(_ name: String, bekannt: [String: Double]) -> String {
        let tokens = name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        for token in tokens where bekannt[token] != nil { return token }
        return tokens.first ?? name.lowercased()
    }

    private func double(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }

    public func estimate(components: [EstimateComponent], scope: ScopeFlags, distanceKm: Double? = nil) -> KorpusBandEstimate {
        estimate(spec(components: components, scope: scope, distanceKm: distanceKm))
    }

    public func spec(components: [EstimateComponent], scope: ScopeFlags, distanceKm: Double? = nil) -> KorpusKitchenSpec {
        var korpen = 0.0
        var drawers = 0
        let materials = components.reduce(into: Set<String>()) { $0.formUnion($1.materials) }
        for c in components {
            switch c.componentClass {
            case .kitchenRun:       korpen += (c.widthM ?? c.quantity) / 0.6
            case .baseUnit:         korpen += max(1.0, (c.widthM ?? 0.6) / 0.6)
            case .tallCabinetBlock: korpen += max(1.0, (c.widthM ?? c.quantity) / 0.6)
            case .island:           korpen += ((c.widthM ?? c.quantity) / 0.6) * 1.6
            case .aggregateKitchen:
                if let w = c.widthM { korpen += w / 0.6 }
                else if c.unit == "lfm" || c.unit == "m" { korpen += c.quantity / 0.6 }
            default: break   
            }
            drawers += c.drawerCount
        }
        let exec = FrontExecution.infer(from: materials)

        let holzDrawers = FrontExecution.infer(from: materials) == .furnier
            || materials.contains(where: { ["massiv", "eiche", "nussbaum"].contains($0.lowercased()) }) ? drawers : 0
        let legraDrawers = drawers - holzDrawers
        let basis: MontageBasis = scope.includesInstallation ? .inklusive : (scope.notes.contains { $0.lowercased().contains("montage") } ? .separat : .unbekannt)
        let spec = KorpusKitchenSpec(korpusCount: Int(korpen.rounded()), frontExecution: exec,
                                     drawersLegrabox: legraDrawers, drawersHolz: holzDrawers,
                                     distanceKm: distanceKm, montageBasisHinweis: basis)
        return spec
    }
}

private func moneyK(_ d: Decimal) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0; f.locale = Locale(identifier: "de_DE")
    return (f.string(from: NSDecimalNumber(decimal: d)) ?? "\(d)") + " €"
}
