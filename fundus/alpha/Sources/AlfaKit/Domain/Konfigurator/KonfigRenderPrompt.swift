import Foundation

public enum KonfigRenderPrompt {
    public static func kompiliere(draft: KonfigEntwurf, stil: StilPreset = .fotorealistisch) -> KompilierterPrompt {
        let szene = szeneBlock(draft)
        let geometrie = geometrieBlock(draft)
        let materialien = materialBlock(draft)
        let stilText = stil.promptText
        let verbote = verboteBlock()
        let vollText = [
            "SZENE:\n\(szene)",
            "GEOMETRIE (verbindlich):\n\(geometrie)",
            "MATERIALIEN:\n\(materialien)",
            "STIL:\n\(stilText)",
            "NICHT:\n\(verbote)"
        ].joined(separator: "\n\n")
        return KompilierterPrompt(blockSzene: szene, blockGeometrie: geometrie,
                                  blockMaterialien: materialien, blockStil: stilText,
                                  blockVerbote: verbote, vollText: vollText)
    }

    public static func referenzListe(draft: KonfigEntwurf) -> [(name: String, ref: String)] {
        var referenzen: [(String, String)] = []
        if case .foto(let pfad) = draft.raumBezug {
            referenzen.append(("Kundenfoto Bestand", pfad))
        }
        for (label, angabe) in draft.material.blattZeilen {
            if let asset = angabe.assetRef, asset.isEmpty == false {
                referenzen.append(("Material \(label): \(angabe.text)", asset))
            }
        }
        return referenzen
    }

    static func szeneBlock(_ draft: KonfigEntwurf) -> String {
        var teile = ["Fotorealistisches Interieur-Rendering einer maßgefertigten Küche (MYKILOS-Studio, Hamburg)."]
        switch draft.raumBezug {
        case .freieMasse(let b, let t, let h):
            teile.append("Raum ca. \(mm(b)) × \(mm(t)) m Grundfläche, Deckenhöhe \(mm(h)) m.")
        case .foto:
            teile.append("Bestandsraum wie auf dem angehängten Kundenfoto — Architektur, Fenster und Lichtstimmung exakt übernehmen.")
        case .aufmass, .skizze:
            teile.append("Raumgeometrie gemäß Aufmaß/Skizze des Projekts.")
        case .keiner:
            teile.append("Neutraler heller Altbau-Raum mit Fenster seitlich.")
        }
        return teile.joined(separator: " ")
    }

    static func geometrieBlock(_ draft: KonfigEntwurf) -> String {
        guard draft.zonen.isEmpty == false else { return "Noch keine Möbel-Zonen definiert." }
        var rowItems: [String] = []
        for zone in draft.zonen {
            var satz = "\(zone.displayName): \(zone.breiteGesamtMM) mm breit, \(zone.korpusHoeheMM + zone.sockelMM) mm hoch"
            satz += ", \(zone.segmente.count) Front-Segmente (\(zone.segmente.map { "\($0.widthMm)" }.joined(separator: "/")) mm)"
            let schub = zone.schubkaestenGesamt
            if schub > 0 { satz += ", davon \(schub) Schubkasten-Fronten" }
            let geraete = zone.geraeteSlots.map(\.kategorie.displayName)
            if geraete.isEmpty == false { satz += ", integrierte Geräte: \(geraete.joined(separator: ", "))" }
            if zone.typ.hatArbeitsplatte { satz += ", durchgehende Arbeitsplatte" }
            if zone.ueberstandMM > 0 { satz += " mit \(zone.ueberstandMM) mm Tresen-Überstand" }
            rowItems.append(satz + ".")
        }
        rowItems.append("Fugenbild exakt einhalten: durchlaufende, gleichmäßige Fugen; Proportionen der Segmentbreiten sind verbindlich.")
        return rowItems.joined(separator: "\n")
    }

    static func materialBlock(_ draft: KonfigEntwurf) -> String {
        var rowItems: [String] = []
        for (label, angabe) in draft.material.blattZeilen where angabe.isEmpty == false {
            var rowItem = "\(label): \(angabe.text)"
            if angabe.assetRef != nil { rowItem += " (Materialmuster als Referenzbild angehängt — exakt treffen)" }
            rowItems.append(rowItem)
        }
        if rowItems.isEmpty { return "Materialien noch offen — zurückhaltend helle, matte Flächen." }
        return rowItems.joined(separator: "\n")
    }

    static func verboteBlock() -> String {
        [
            "Keine zusätzlichen Möbel oder Deko-Objekte erfinden, die nicht beschrieben sind.",
            "Keine Griffe darstellen, wenn grifflos/PTO spezifiziert ist.",
            "Keine Marken-Logos, kein Text im Bild, keine Wasserzeichen.",
            "Proportionen und Segment-Aufteilung nicht verändern."
        ].joined(separator: "\n")
    }

    private static func mm(_ value: Int) -> String {
        String(format: "%.1f", Double(value) / 1000).replacingOccurrences(of: ".", with: ",")
    }
}
