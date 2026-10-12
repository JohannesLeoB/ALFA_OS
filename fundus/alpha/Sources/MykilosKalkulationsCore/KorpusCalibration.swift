import Foundation

public enum KorpusKalibrierZiel: Equatable, Codable, Sendable, Hashable {
    case fixkostenSockel
    case variabelProKorpus
    case frontFaktor(FrontExecution)

    case werkstattFaktor(String)
    case montageStundensatz
    case schubHolz
    case schubLegrabox
    case anfahrtProKm

    public var schaetzmodellSchluessel: String {
        switch self {
        case .fixkostenSockel: "fixkosten_sockel"
        case .variabelProKorpus: "variabel_pro_korpus"
        case .frontFaktor(let f): "front_faktor_\(f.rawValue)"
        case .werkstattFaktor(let w): "werkstatt_faktor_\(w)"
        case .montageStundensatz: "montage_stundensatz_default"
        case .schubHolz: "schub_holz_eur"
        case .schubLegrabox: "schub_legrabox_eur"
        case .anfahrtProKm: "anfahrt_pro_km"
        }
    }

    public var displayName: String {
        switch self {
        case .fixkostenSockel: "Fixkosten-Sockel"
        case .variabelProKorpus: "€/Korpus (Baseline)"
        case .frontFaktor(let f): "Front-Faktor \(f.label)"
        case .werkstattFaktor(let w): "Werkstatt-Faktor \(w)"
        case .montageStundensatz: "Montage-Stundensatz"
        case .schubHolz: "Schub Holz-massiv"
        case .schubLegrabox: "Schub Legrabox"
        case .anfahrtProKm: "Anfahrt €/km"
        }
    }

    public static func von(schluessel: String) -> KorpusKalibrierZiel? {
        switch schluessel {
        case "fixkosten_sockel": return .fixkostenSockel
        case "variabel_pro_korpus": return .variabelProKorpus
        case "montage_stundensatz_default": return .montageStundensatz
        case "schub_holz_eur": return .schubHolz
        case "schub_legrabox_eur": return .schubLegrabox
        case "anfahrt_pro_km": return .anfahrtProKm
        default:
            if let raw = schluessel.stripPrefix("front_faktor_"), let f = FrontExecution(rawValue: raw) {
                return .frontFaktor(f)
            }
            if let w = schluessel.stripPrefix("werkstatt_faktor_") {
                return .werkstattFaktor(w)
            }
            return nil
        }
    }
}

private extension String {
    func stripPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}

public struct KorpusAdjustment: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sessionID: String
    public let createdAt: Date
    public let ziel: KorpusKalibrierZiel

    public let modellWert: Double

    public let beobachteterWert: Double
    public let reason: EstimateAdjustmentReason
    public let note: String
    public let status: LearningRecordStatus

    public init(id: String = UUID().uuidString, sessionID: String, createdAt: Date = Date(),
                ziel: KorpusKalibrierZiel, modellWert: Double, beobachteterWert: Double,
                reason: EstimateAdjustmentReason, note: String = "", status: LearningRecordStatus = .active) {
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.ziel = ziel
        self.modellWert = modellWert
        self.beobachteterWert = beobachteterWert
        self.reason = reason
        self.note = note
        self.status = status
    }

    public var percentDelta: Double {
        modellWert == 0 ? 0 : (beobachteterWert - modellWert) / modellWert * 100
    }
}

public struct KorpusCalibrationCandidate: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let createdAt: Date
    public let ziel: KorpusKalibrierZiel
    public let sampleCount: Int
    public let weightedPercentDelta: Double

    public let aktuellerWert: Double

    public let vorgeschlagenerWert: Double
    public let adjustmentIDs: [String]
    public let status: LearningRecordStatus
    public let note: String

    public init(id: String, createdAt: Date = Date(), ziel: KorpusKalibrierZiel, sampleCount: Int,
                weightedPercentDelta: Double, aktuellerWert: Double, vorgeschlagenerWert: Double,
                adjustmentIDs: [String], status: LearningRecordStatus, note: String) {
        self.id = id
        self.createdAt = createdAt
        self.ziel = ziel
        self.sampleCount = sampleCount
        self.weightedPercentDelta = weightedPercentDelta
        self.aktuellerWert = aktuellerWert
        self.vorgeschlagenerWert = vorgeschlagenerWert
        self.adjustmentIDs = adjustmentIDs
        self.status = status
        self.note = note
    }
}

public struct KorpusKalibrierPromotion: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let candidateID: String
    public let createdAt: Date
    public let ziel: KorpusKalibrierZiel
    public let alterWert: Double
    public let neuerWert: Double
    public let sampleCount: Int

    public let airtableGeschrieben: Bool
    public let airtableFehler: String?

    public init(id: String = UUID().uuidString, candidateID: String, createdAt: Date = Date(),
                ziel: KorpusKalibrierZiel, alterWert: Double, neuerWert: Double, sampleCount: Int,
                airtableGeschrieben: Bool, airtableFehler: String? = nil) {
        self.id = id
        self.candidateID = candidateID
        self.createdAt = createdAt
        self.ziel = ziel
        self.alterWert = alterWert
        self.neuerWert = neuerWert
        self.sampleCount = sampleCount
        self.airtableGeschrieben = airtableGeschrieben
        self.airtableFehler = airtableFehler
    }
}
