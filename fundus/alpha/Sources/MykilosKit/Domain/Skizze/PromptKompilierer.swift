import Foundation

public protocol PromptKompilierend {
    func kompiliere(dokument: SkizzenDokument, referenzen: [MaterialRef], stil: StilPreset) -> KompilierterPrompt
}

public struct VorlagenKompilierer: PromptKompilierend {
    public init() {}

    public func kompiliere(dokument: SkizzenDokument, referenzen: [MaterialRef],
                           stil: StilPreset) -> KompilierterPrompt {
        let szene = PromptVorlagen.szene
        let geometrie = Self.blockGeometrie(dokument: dokument)
        let materialien = Self.blockMaterialien(dokument: dokument, referenzen: referenzen)
        let stilText = stil.promptText
        let verbote = PromptVorlagen.verbote
        let full = PromptVorlagen.volltext(szene: szene, geometrie: geometrie,
                                           materialien: materialien, stil: stilText, verbote: verbote)
        return KompilierterPrompt(blockSzene: szene, blockGeometrie: geometrie,
                                  blockMaterialien: materialien, blockStil: stilText,
                                  blockVerbote: verbote, vollText: full)
    }

    static func blockGeometrie(dokument: SkizzenDokument) -> String {
        var rowItems: [String] = []
        for layer in dokument.exportLayers {
            switch layer.art {
            case .neu:
                for obj in layer.objekte where obj.istGefuellt {
                    let color = dokument.slots.first { $0.id == obj.fuellSlotID }?.color.display ?? "farbig"
                    rowItems.append("• \(color) markiertes Volumen = \(name(obj, layer))")
                }
            case .entfernen:
                for obj in layer.objekte {
                    rowItems.append("• Entfernen: \(name(obj, layer))")
                }
            case .stock, .notiz:
                break
            }
        }
        for anker in dokument.massAnker {
            rowItems.append("• Maß — \(anker.beschreibung)")
        }
        return rowItems.isEmpty ? "Keine neuen Volumen markiert." : rowItems.joined(separator: "\n")
    }

    private static func name(_ obj: SkizzenObjekt, _ layer: SkizzenLayer) -> String {
        let b = obj.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return b.isEmpty ? layer.name : b
    }

    static func blockMaterialien(dokument: SkizzenDokument, referenzen: [MaterialRef]) -> String {
        let benutzt = dokument.benutzteSlotIDs
        var rowItems: [String] = []
        for slot in dokument.slots {
            guard benutzt.contains(slot.id), let material = slot.zugeordnetesMaterial else { continue }
            guard let idx = referenzen.firstIndex(where: { $0.id == material.id }) else { continue }
            rowItems.append("• Alle Flächen in \(slot.color.display) (\(slot.label)) = "
                          + "Referenz \(idx + 1) (\(material.promptText))")
        }
        return rowItems.isEmpty ? "Keine Material-Zuordnung." : rowItems.joined(separator: "\n")
    }
}

public struct AssistierterKompilierer: PromptKompilierend {
    private let basis = VorlagenKompilierer()
    public init() {}

    public func kompiliere(dokument: SkizzenDokument, referenzen: [MaterialRef],
                           stil: StilPreset) -> KompilierterPrompt {
        basis.kompiliere(dokument: dokument, referenzen: referenzen, stil: stil)
    }
}
