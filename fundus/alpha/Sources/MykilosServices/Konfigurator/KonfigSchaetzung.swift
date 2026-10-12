import Foundation
import MykilosKit
import MykilosKalkulationsCore

public struct KonfigSchaetzErgebnis: Equatable, Sendable {
    public let gewerkeBand: PriceBand

    public let geraeteSummeEK: Decimal

    public let geraeteOhnePreis: Int

    public let gesamtBand: PriceBand
    public let korpusAnzahl: Int
    public let frontExecution: FrontExecution
    public let schubLegrabox: Int
    public let schubHolz: Int

    public let annahmen: [String]

    public let ausschluesse: [String]

    public let parameterNotiz: String

    public func delta(zu andere: KonfigSchaetzErgebnis) -> Decimal {
        gesamtBand.expected - andere.gesamtBand.expected
    }
}

public enum KonfigSchaetzung {
    public static func spec(fuer draft: KonfigEntwurf, werkstatt: String? = nil,
                            distanceKm: Double? = nil) -> KorpusKitchenSpec {
        var legrabox = 0
        var holz = 0
        for zone in draft.zonen {
            for segment in zone.segmente {
                for fach in segment.faecher {
                    if case .schubkaesten(let count, let material) = fach.ausstattung {
                        switch material {
                        case .legrabox: legrabox += count
                        case .holzMassiv: holz += count
                        }
                    }
                }
            }
        }

        let front: FrontExecution
        if let paletteID = draft.material.front.paletteID,
           let key = KonfigPalette.entry(id: paletteID)?.faktorSchluessel {
            front = FrontExecution.infer(from: [key])
        } else {
            front = FrontExecution.infer(from: [draft.material.front.text])
        }
        return KorpusKitchenSpec(korpusCount: draft.korpusAnzahl,
                                 frontExecution: front,
                                 drawersLegrabox: legrabox,
                                 drawersHolz: holz,
                                 distanceKm: distanceKm,
                                 montageBasisHinweis: .unbekannt,
                                 montageStundensatz: nil,
                                 werkstatt: werkstatt)
    }

    public static func schaetze(draft: KonfigEntwurf,
                                params: KorpusModelParameters,
                                werkstatt: String? = nil,
                                distanceKm: Double? = nil,
                                geraeteEK: (String) -> Decimal?) -> KonfigSchaetzErgebnis {
        let spec = spec(fuer: draft, werkstatt: werkstatt, distanceKm: distanceKm)
        let estimator = KorpusBandEstimator(params: params)
        let korpus = estimator.estimate(spec)

        var geraeteSumme = Decimal(0)
        var ohnePreis = 0
        for slot in draft.geraeteSlots {
            if let artikel = slot.artikel, let ek = geraeteEK(artikel.artikelID) {
                geraeteSumme += ek
            } else {
                ohnePreis += 1
            }
        }

        let total = PriceBand(low: korpus.band.low + geraeteSumme,
                               expected: korpus.band.expected + geraeteSumme,
                               high: korpus.band.high + geraeteSumme,
                               currency: korpus.band.currency)

        var annahmen = korpus.assumptions
        if ohnePreis > 0 {
            annahmen.append("\(ohnePreis) Geräte-Slot(s) ohne Artikel/EK — Geräteschicht unvollständig, Gesamtwert entsprechend zu niedrig.")
        }

        let notiz = parameterNotiz(korpus: korpus, params: params)
        return KonfigSchaetzErgebnis(gewerkeBand: korpus.band,
                                     geraeteSummeEK: geraeteSumme,
                                     geraeteOhnePreis: ohnePreis,
                                     gesamtBand: total,
                                     korpusAnzahl: korpus.korpusCount,
                                     frontExecution: korpus.frontExecution,
                                     schubLegrabox: spec.drawersLegrabox,
                                     schubHolz: spec.drawersHolz,
                                     annahmen: annahmen,
                                     ausschluesse: korpus.excludes,
                                     parameterNotiz: notiz)
    }

    public static func blattNotiz(korpusAnzahl: Int, front: FrontExecution) -> String {
        "\(korpusAnzahl) Korpen · \(front.label)"
    }

    static func parameterNotiz(korpus: KorpusBandEstimate, params: KorpusModelParameters) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "de_DE")
        let sockel = f.string(from: NSDecimalNumber(decimal: params.fixkostenSockel)) ?? "?"
        let variabel = f.string(from: NSDecimalNumber(decimal: params.variabelProKorpus)) ?? "?"
        return "\(korpus.korpusCount) Korpen · \(korpus.frontExecution.label) · Sockel \(sockel) € + \(variabel) €/Korpus"
    }

    public static func spanneText(_ band: PriceBand) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "de_DE")
        let low = f.string(from: NSDecimalNumber(decimal: band.low)) ?? "?"
        let high = f.string(from: NSDecimalNumber(decimal: band.high)) ?? "?"
        return "\(low) – \(high) €"
    }

    public static func deltaText(_ delta: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "de_DE")
        let betrag = f.string(from: NSDecimalNumber(decimal: abs(delta))) ?? "?"
        if delta > 0 { return "+\(betrag) €" }
        if delta < 0 { return "−\(betrag) €" }
        return "±0 €"
    }
}

public actor KonfigSchaetzService {
    private let paramProvider: SchaetzmodellParameterProvider
    private var paramsCache: KorpusModelParameters?

    private var ekByArtikelID: [String: Decimal] = [:]

    public init(paramProvider: SchaetzmodellParameterProvider = SchaetzmodellParameterProvider()) {
        self.paramProvider = paramProvider
    }

    public func setzeArtikelEK(_ map: [String: Decimal]) {
        ekByArtikelID = map
    }

    public func parameter() async -> KorpusModelParameters {
        if let paramsCache { return paramsCache }
        let p = await paramProvider.load()
        paramsCache = p
        return p
    }

    public func schaetze(draft: KonfigEntwurf, werkstatt: String? = nil) async -> KonfigSchaetzErgebnis {
        let params = await parameter()
        let ek = ekByArtikelID
        return KonfigSchaetzung.schaetze(draft: draft, params: params,
                                         werkstatt: werkstatt) { ek[$0] }
    }
}
