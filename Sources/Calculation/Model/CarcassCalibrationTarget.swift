enum CarcassCalibrationTarget: Equatable, Hashable, Sendable {
    case fixedBase
    case variablePerCarcass
    case frontFactor(FrontExecution)
    case workshopFactor(String)
    case installationHourlyRate
    case drawerSolid
    case drawerLegrabox
    case travelPerKm

    var key: String {
        switch self {
        case .fixedBase: "fixkosten_sockel"
        case .variablePerCarcass: "variabel_pro_korpus"
        case .frontFactor(let front): "front_faktor_\(front.rawValue)"
        case .workshopFactor(let workshop): "werkstatt_faktor_\(workshop)"
        case .installationHourlyRate: "montage_stundensatz_default"
        case .drawerSolid: "schub_holz_eur"
        case .drawerLegrabox: "schub_legrabox_eur"
        case .travelPerKm: "anfahrt_pro_km"
        }
    }

    var localizationKey: String {
        switch self {
        case .workshopFactor: "calc.carcassTarget.werkstatt_faktor"
        default: "calc.carcassTarget.\(key)"
        }
    }

    var detail: String {
        if case .workshopFactor(let workshop) = self { return workshop }
        return ""
    }

    init?(key: String) {
        switch key {
        case "fixkosten_sockel": self = .fixedBase
        case "variabel_pro_korpus": self = .variablePerCarcass
        case "montage_stundensatz_default": self = .installationHourlyRate
        case "schub_holz_eur": self = .drawerSolid
        case "schub_legrabox_eur": self = .drawerLegrabox
        case "anfahrt_pro_km": self = .travelPerKm
        default:
            if key.hasPrefix("front_faktor_"), let front = FrontExecution(rawValue: String(key.dropFirst("front_faktor_".count))) {
                self = .frontFactor(front)
            } else if key.hasPrefix("werkstatt_faktor_") {
                self = .workshopFactor(String(key.dropFirst("werkstatt_faktor_".count)))
            } else {
                return nil
            }
        }
    }
}
