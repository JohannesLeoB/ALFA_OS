import Foundation

public struct CarcassParameters: Equatable, Sendable {
    var fixedBase: Decimal
    var variablePerCarcass: Decimal
    var frontMultipliers: [String: Double]
    var drawerLegraboxPrice: Decimal
    var drawerSolidPrice: Decimal
    var travelPerKm: Decimal
    var travelFreeKm: Double
    var installationHoursPerCarcass: Double
    var installationHourlyRate: Decimal
    var bandLow: Double
    var bandHigh: Double
    var bandLowThin: Double
    var bandHighThin: Double
    var workshopFactors: [String: Double]

    func frontMultiplier(for front: FrontExecution) -> Double {
        frontMultipliers[front.rawValue] ?? front.variableMultiplier
    }

    func workshopFactor(for name: String?) -> Double {
        guard let name, name.isEmpty == false else { return 1.0 }
        if let hit = workshopFactors[String(name.lowercased().filter { $0.isLetter || $0.isNumber })] { return hit }
        for token in name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            if let hit = workshopFactors[String(token)] { return hit }
        }
        return 1.0
    }

    public static func seed(workshopFactors: WorkshopFactors = WorkshopFactors()) -> CarcassParameters {
        CarcassParameters(
            fixedBase: 6500,
            variablePerCarcass: 685,
            frontMultipliers: Dictionary(uniqueKeysWithValues: FrontExecution.allCases.map { ($0.rawValue, $0.variableMultiplier) }),
            drawerLegraboxPrice: 70,
            drawerSolidPrice: 132,
            travelPerKm: 8,
            travelFreeKm: 30,
            installationHoursPerCarcass: 3.3,
            installationHourlyRate: 81,
            bandLow: 0.72,
            bandHigh: 1.40,
            bandLowThin: 0.62,
            bandHighThin: 1.58,
            workshopFactors: workshopFactors.values)
    }

    public static func from(parameters p: [String: Double], fallback: CarcassParameters) -> CarcassParameters {
        func money(_ key: String, _ fallbackValue: Decimal) -> Decimal { p[key].map { Decimal($0) } ?? fallbackValue }
        func number(_ key: String, _ fallbackValue: Double) -> Double { p[key] ?? fallbackValue }
        var fronts = fallback.frontMultipliers
        for front in FrontExecution.allCases {
            if let value = p["front_faktor_\(front.rawValue)"] { fronts[front.rawValue] = value }
        }
        var workshops = fallback.workshopFactors
        for (key, value) in p where key.hasPrefix("werkstatt_faktor_") {
            workshops[String(key.dropFirst("werkstatt_faktor_".count))] = value
        }
        return CarcassParameters(
            fixedBase: money("fixkosten_sockel", fallback.fixedBase),
            variablePerCarcass: money("variabel_pro_korpus", fallback.variablePerCarcass),
            frontMultipliers: fronts,
            drawerLegraboxPrice: money("schub_legrabox_eur", fallback.drawerLegraboxPrice),
            drawerSolidPrice: money("schub_holz_eur", fallback.drawerSolidPrice),
            travelPerKm: money("anfahrt_pro_km", fallback.travelPerKm),
            travelFreeKm: number("anfahrt_frei_km", fallback.travelFreeKm),
            installationHoursPerCarcass: number("montage_stunden_pro_korpus", fallback.installationHoursPerCarcass),
            installationHourlyRate: money("montage_stundensatz_default", fallback.installationHourlyRate),
            bandLow: number("band_low", fallback.bandLow),
            bandHigh: number("band_high", fallback.bandHigh),
            bandLowThin: number("band_low_thin", fallback.bandLowThin),
            bandHighThin: number("band_high_thin", fallback.bandHighThin),
            workshopFactors: workshops)
    }
}
