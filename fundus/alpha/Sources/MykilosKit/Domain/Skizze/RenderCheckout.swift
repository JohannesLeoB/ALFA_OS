import Foundation

public enum RenderEngine: String, Codable, CaseIterable, Sendable {
    case fireflyManuell
    case nb2
    case nbPro

    public var display: String {
        switch self {
        case .fireflyManuell: return "Firefly (manuell)"
        case .nb2:            return "Nano Banana 2"
        case .nbPro:          return "Nano Banana Pro"
        }
    }

    public var heuteVerfuegbar: Bool { self == .fireflyManuell }
}

public enum StilPreset: String, Codable, CaseIterable, Sendable {
    case fotorealistisch
    case architekturEditorial
    case innenarchitekturWeich
    case skizzenhaft

    public var display: String {
        switch self {
        case .fotorealistisch:      return "Fotorealistisch"
        case .architekturEditorial: return "Architektur — editorial"
        case .innenarchitekturWeich: return "Innenarchitektur — weiches Licht"
        case .skizzenhaft:          return "Skizzenhaft"
        }
    }
    public var promptText: String {
        switch self {
        case .fotorealistisch:
            return "Fotorealistische Wiedergabe, natürliche Materialtreue, physikalisch "
                + "korrekte Schatten und Reflexe, hohe Detailschärfe."
        case .architekturEditorial:
            return "Editoriale Architekturfotografie, ruhige Komposition, gedeckte Farbwelt, "
                + "klare Kanten, gleichmäßiges Licht — wie eine hochwertige Studio-Aufnahme."
        case .innenarchitekturWeich:
            return "Innenarchitektur-Visualisierung mit weichem Tageslicht, warmen Halbschatten "
                + "und feiner Textur — einladend, aber präzise."
        case .skizzenhaft:
            return "Halbrealistische Visualisierung mit sichtbarem Zeichen-Charakter, "
                + "reduzierte Details, klare Volumen — für die frühe Beratung."
        }
    }
}

public struct KompilierterPrompt: Codable, Equatable, Sendable {
    public var blockSzene: String
    public var blockGeometrie: String
    public var blockMaterialien: String
    public var blockStil: String
    public var blockVerbote: String
    public var vollText: String

    public init(blockSzene: String, blockGeometrie: String, blockMaterialien: String,
                blockStil: String, blockVerbote: String, vollText: String) {
        self.blockSzene = blockSzene
        self.blockGeometrie = blockGeometrie
        self.blockMaterialien = blockMaterialien
        self.blockStil = blockStil
        self.blockVerbote = blockVerbote
        self.vollText = vollText
    }
}

public struct RenderRezept: Codable, Equatable, Sendable {
    public var substratExportRef: String
    public var referenzen: [MaterialRef]
    public var prompt: KompilierterPrompt
    public var engine: RenderEngine
    public var stil: StilPreset
    public var manuellUeberschrieben: Bool

    public init(substratExportRef: String, referenzen: [MaterialRef], prompt: KompilierterPrompt,
                engine: RenderEngine, stil: StilPreset, manuellUeberschrieben: Bool = false) {
        self.substratExportRef = substratExportRef
        self.referenzen = referenzen
        self.prompt = prompt
        self.engine = engine
        self.stil = stil
        self.manuellUeberschrieben = manuellUeberschrieben
    }
}

public enum VersionStatus: String, Codable, CaseIterable, Sendable {
    case draft, freigegeben, master, verworfen
    public var display: String {
        switch self {
        case .draft:     return "Entwurf"
        case .freigegeben: return "Freigegeben"
        case .master:      return "Master"
        case .verworfen:   return "Verworfen"
        }
    }
}

public struct RenderVersion: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var elternVersionID: UUID?
    public var rezept: RenderRezept
    public var ergebnisBildRef: String?
    public var status: VersionStatus
    public var notiz: String?
    public var erstelltAm: Date

    public init(id: UUID = UUID(), elternVersionID: UUID? = nil, rezept: RenderRezept,
                ergebnisBildRef: String? = nil, status: VersionStatus = .draft,
                notiz: String? = nil, erstelltAm: Date = Date()) {
        self.id = id
        self.elternVersionID = elternVersionID
        self.rezept = rezept
        self.ergebnisBildRef = ergebnisBildRef
        self.status = status
        self.notiz = notiz
        self.erstelltAm = erstelltAm
    }
}

public enum AuftragsArt: String, Codable, Sendable {
    case skizzenRender
    case cadRender
}

public struct RenderAuftrag: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var art: AuftragsArt
    public var skizzenDokumentID: UUID
    public var versionen: [RenderVersion]
    public var erstelltAm: Date

    public init(id: UUID = UUID(), art: AuftragsArt = .skizzenRender, skizzenDokumentID: UUID,
                versionen: [RenderVersion] = [], erstelltAm: Date = Date()) {
        self.id = id
        self.art = art
        self.skizzenDokumentID = skizzenDokumentID
        self.versionen = versionen
        self.erstelltAm = erstelltAm
    }

    public func mitMaster(_ versionID: UUID) -> RenderAuftrag {
        guard versionen.contains(where: { $0.id == versionID }) else { return self }
        var kopie = self
        for i in kopie.versionen.indices {
            if kopie.versionen[i].id == versionID {
                kopie.versionen[i].status = .master
            } else if kopie.versionen[i].status == .master {
                kopie.versionen[i].status = .freigegeben
            }
        }
        return kopie
    }

    public var master: RenderVersion? { versionen.first { $0.status == .master } }
}
