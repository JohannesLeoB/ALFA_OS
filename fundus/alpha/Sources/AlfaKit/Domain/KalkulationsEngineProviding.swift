import Foundation

public protocol KalkulationsEngineProviding: AnyObject, Sendable {
    func schaetze(projektID: String?, freitext: String) async throws -> KostenSchaetzung
    func schaetze(projektID: String?, freitext: String, override: EstimateOverride) async throws -> KostenSchaetzung
    func geraetepreis(suchbegriff: String) async -> Double?

    func recordAdjustment(schaetzungsID: String, faktor: Double, ground: String, lernen: Bool) async throws

    func lernUebersicht() async throws -> KalkulationsLernStand

    func promote(candidateID: String) async throws
}

public extension KalkulationsEngineProviding {
    func recordAdjustment(schaetzungsID: String, faktor: Double, ground: String) async throws {
        try await recordAdjustment(schaetzungsID: schaetzungsID, faktor: faktor, ground: ground, lernen: false)
    }
}

public struct KostenSchaetzung: Sendable, Equatable {
    public let schaetzungsID: String
    public let projektID: String
    public let minNetto: Double
    public let maxNetto: Double
    public let mitteNetto: Double
    public let confidence: Double
    public let evidenceCount: Int
    public let kostenboden: Double
    public let kostenbodenRatio: Double
    public let topEvidences: [PriceEvidence]

    public let modellLabel: String?

    public let hints: [String]

    public let lines: [EstimateBreakdownLine]

    public let excludes: [String]

    public init(
        schaetzungsID: String,
        projektID: String,
        minNetto: Double,
        maxNetto: Double,
        mitteNetto: Double,
        confidence: Double,
        evidenceCount: Int,
        kostenboden: Double,
        kostenbodenRatio: Double,
        topEvidences: [PriceEvidence],
        modellLabel: String? = nil,
        hints: [String] = [],
        lines: [EstimateBreakdownLine] = [],
        excludes: [String] = []
    ) {
        self.schaetzungsID = schaetzungsID
        self.projektID = projektID
        self.minNetto = minNetto
        self.maxNetto = maxNetto
        self.mitteNetto = mitteNetto
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.kostenboden = kostenboden
        self.kostenbodenRatio = kostenbodenRatio
        self.topEvidences = topEvidences
        self.modellLabel = modellLabel
        self.hints = hints
        self.lines = lines
        self.excludes = excludes
    }
}

public struct PriceEvidence: Sendable, Equatable {
    public let lieferant: String
    public let dokument: String
    public let page: Int?
    public let originalZitat: String
    public let nettoPreis: Double

    public init(
        lieferant: String,
        dokument: String,
        page: Int?,
        originalZitat: String,
        nettoPreis: Double
    ) {
        self.lieferant = lieferant
        self.dokument = dokument
        self.page = page
        self.originalZitat = originalZitat
        self.nettoPreis = nettoPreis
    }
}

public struct KalkulationsLernStand: Sendable, Equatable {
    public let sessions: Int
    public let adjustments: Int
    public let outliers: Int
    public let aktiveFaktoren: [KalkulationsFaktor]
    public let candidates: [KalkulationsKandidat]

    public init(
        sessions: Int,
        adjustments: Int,
        outliers: Int,
        aktiveFaktoren: [KalkulationsFaktor],
        candidates: [KalkulationsKandidat]
    ) {
        self.sessions = sessions
        self.adjustments = adjustments
        self.outliers = outliers
        self.aktiveFaktoren = aktiveFaktoren
        self.candidates = candidates
    }

    public var isEmpty: Bool { aktiveFaktoren.isEmpty && candidates.isEmpty }
}

public struct KalkulationsFaktor: Sendable, Equatable, Identifiable {
    public let id: String
    public let grundLabel: String
    public let zielLabel: String
    public let prozent: Double
    public let sampleCount: Int

    public init(id: String, grundLabel: String, zielLabel: String, prozent: Double, sampleCount: Int) {
        self.id = id
        self.grundLabel = grundLabel
        self.zielLabel = zielLabel
        self.prozent = prozent
        self.sampleCount = sampleCount
    }
}

public struct KalkulationsKandidat: Sendable, Equatable, Identifiable {
    public let id: String
    public let grundLabel: String
    public let zielLabel: String
    public let prozent: Double
    public let sampleCount: Int
    public let statusLabel: String

    public init(id: String, grundLabel: String, zielLabel: String, prozent: Double, sampleCount: Int, statusLabel: String) {
        self.id = id
        self.grundLabel = grundLabel
        self.zielLabel = zielLabel
        self.prozent = prozent
        self.sampleCount = sampleCount
        self.statusLabel = statusLabel
    }
}

public struct EstimateBreakdownLine: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, Equatable {
        case estimated
        case fixed
        case open
    }

    public let label: String
    public let amountNet: Double?
    public let kind: Kind

    public init(label: String, amountNet: Double?, kind: Kind) {
        self.label = label
        self.amountNet = amountNet
        self.kind = kind
    }
}

public struct EstimateOverride: Sendable, Equatable {
    public var korpusCount: Int?
    public var frontExecution: String?
    public var drawersLegrabox: Int?
    public var drawersHolz: Int?
    public var workshop: String?
    public var distanceKm: Double?

    public init(korpusCount: Int? = nil, frontExecution: String? = nil,
                drawersLegrabox: Int? = nil, drawersHolz: Int? = nil,
                workshop: String? = nil, distanceKm: Double? = nil) {
        self.korpusCount = korpusCount
        self.frontExecution = frontExecution
        self.drawersLegrabox = drawersLegrabox
        self.drawersHolz = drawersHolz
        self.workshop = workshop
        self.distanceKm = distanceKm
    }

    public var isEmpty: Bool {
        korpusCount == nil && frontExecution == nil && drawersLegrabox == nil
            && drawersHolz == nil && workshop == nil && distanceKm == nil
    }

    public var openFields: [String] {
        var out: [String] = []
        if korpusCount == nil { out.append("Korpusanzahl") }
        if frontExecution == nil { out.append("Ausführung der Fronten") }
        if workshop == nil { out.append("Werkstatt") }
        return out
    }
}
