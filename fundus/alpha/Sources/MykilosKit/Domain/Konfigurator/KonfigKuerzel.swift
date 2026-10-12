import Foundation

public enum KonfigKuerzel {
    public static let standardBreiteMM = 600

    public static func ausstattung(fuer kuerzel: String) -> Ausstattung? {
        let k = kuerzel.lowercased()
        switch k {
        case "", "t": return .tuerMitFachboeden
        case "or": return .offenesRegal
        case "fa": return .fachboeden
        case "bl": return .blende
        case "sp": return .spuelbecken
        case "mu": return .muellAuszug
        case "le": return .isEmpty
        case "gs": return .geraet(GeraetSlot(kategorie: .geschirrspueler))
        case "bo": return .geraet(GeraetSlot(kategorie: .backofen))
        case "kf": return .geraet(GeraetSlot(kategorie: .kochfeld))
        case "kg", "kk": return .geraet(GeraetSlot(kategorie: .kuehlGefrier))
        case "wm": return .geraet(GeraetSlot(kategorie: .waermeschublade))
        case "ka": return .geraet(GeraetSlot(kategorie: .kaffeevollautomat))
        case "da": return .geraet(GeraetSlot(kategorie: .dunstabzug))
        default:
            return schubkuerzel(k)
        }
    }

    private static func schubkuerzel(_ k: String) -> Ausstattung? {
        guard let match = k.wholeMatch(of: #/([0-9]{1,2})s(h?)/#) else { return nil }
        guard let count = Int(match.1), count >= 1, count <= 10 else { return nil }
        let material: SchubMaterial = match.2.isEmpty ? .legrabox : .holzMassiv
        return .schubkaesten(count: count, material: material)
    }

    public static func segment(fuer token: String) -> KonfigSegment? {
        let t = token.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return nil }

        if let match = t.wholeMatch(of: #/([0-9]{3,4})(.*)/#) {
            guard let width = Int(match.1), width >= 100, width <= 2400 else { return nil }
            let rest = String(match.2).trimmingCharacters(in: .whitespaces)
            guard let ausstattung = ausstattung(fuer: rest) else { return nil }
            return KonfigSegment(widthMm: width, ausstattung: ausstattung)
        }

        guard let ausstattung = ausstattung(fuer: t) else { return nil }
        return KonfigSegment(widthMm: standardBreiteMM, ausstattung: ausstattung)
    }

    public static func parseZeile(_ input: String) -> (segmente: [KonfigSegment], unverstanden: [String]) {
        var segmente: [KonfigSegment] = []
        var unverstanden: [String] = []
        let tokens = input.split(separator: " ").map(String.init)
        var index = 0
        while index < tokens.count {
            let token = tokens[index].trimmingCharacters(in: .whitespaces).lowercased()

            if token.wholeMatch(of: #/[0-9]{3,4}/#) != nil,
               let width = Int(token), width >= 100, width <= 2400,
               index + 1 < tokens.count,
               let ausstattung = ausstattung(fuer: tokens[index + 1].lowercased()) {
                segmente.append(KonfigSegment(widthMm: width, ausstattung: ausstattung))
                index += 2
                continue
            }
            if let s = segment(fuer: token) {
                segmente.append(s)
            } else {
                unverstanden.append(token)
            }
            index += 1
        }
        return (segmente, unverstanden)
    }

    public static let hilfeText = "Breite+Kürzel je Segment: 600t Tür · 3s/3sh Schubkästen (Legrabox/Holz) · sp Spüle · gs GS · mu Müll · bo Backofen · kf Kochfeld · kg Kühl · wm Wärme · ka Kaffee · da Dunst · or offen · fa Fachböden · bl Blende"
}
