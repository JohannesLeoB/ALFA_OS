import Foundation

public enum RegelSchwere: String, Codable, Sendable {
    case hint

    case warnung
}

public enum RegelQuelle: String, Codable, Sendable {
    case belegt

    case annahme
}

public struct RegelHinweis: Equatable, Sendable {
    public var regelID: String
    public var schwere: RegelSchwere
    public var text: String
    public var zonenID: UUID?
    public var segmentID: UUID?

    public init(regelID: String, schwere: RegelSchwere, text: String,
                zonenID: UUID? = nil, segmentID: UUID? = nil) {
        self.regelID = regelID
        self.schwere = schwere
        self.text = text
        self.zonenID = zonenID
        self.segmentID = segmentID
    }
}

public struct KonfigRegel: Sendable {
    public var id: String
    public var title: String
    public var source: RegelQuelle
    public var pruefe: @Sendable (KonfigEntwurf) -> [RegelHinweis]

    public init(id: String, title: String, source: RegelQuelle,
                pruefe: @escaping @Sendable (KonfigEntwurf) -> [RegelHinweis]) {
        self.id = id
        self.title = title
        self.source = source
        self.pruefe = pruefe
    }
}

public enum StudioMasse {
    public static let durchgangMinMM = 1000

    public static let durchgangHartMM = 850

    public static let nischenHoeheMM = 560...600

    public static let arbeitsHoeheMM = 850...950
}

enum KonfigRegelLogik {
    static func gsNebenSpuele(_ draft: KonfigEntwurf) -> [RegelHinweis] {
        var hints: [RegelHinweis] = []
        for zone in draft.zonen {
            let segmente = zone.segmente
            for (index, segment) in segmente.enumerated() {
                let hatGS = segment.alleAusstattungen.contains {
                    if case .geraet(let slot) = $0 { return slot.kategorie == .geschirrspueler }
                    return false
                }
                guard hatGS else { continue }
                let nachbarn = [index - 1, index + 1].compactMap { i in
                    segmente.indices.contains(i) ? segmente[i] : nil
                }
                let spueleDaneben = nachbarn.contains { nachbar in
                    nachbar.alleAusstattungen.contains { ausstattung in
                        if case .spuelbecken = ausstattung { return true }
                        return false
                    }
                }

                let spueleInZone = segmente.contains { s in
                    s.alleAusstattungen.contains { if case .spuelbecken = $0 { return true }; return false }
                }
                if !spueleDaneben {
                    let text = spueleInZone
                        ? "Geschirrspüler ohne Spülen-Nachbarschaft — neben die Spüle rücken?"
                        : "Geschirrspüler in \(zone.displayName), aber keine Spüle in dieser Zone."
                    hints.append(RegelHinweis(regelID: "gs-neben-spuele", schwere: .hint,
                                                 text: text, zonenID: zone.id, segmentID: segment.id))
                }
            }
        }
        return hints
    }

    static func muellNaheSpuele(_ draft: KonfigEntwurf) -> [RegelHinweis] {
        var hints: [RegelHinweis] = []
        for zone in draft.zonen {
            let segmente = zone.segmente
            for (index, segment) in segmente.enumerated() {
                let hatMuell = segment.alleAusstattungen.contains {
                    if case .muellAuszug = $0 { return true }
                    return false
                }
                guard hatMuell else { continue }
                let imUmfeld = [index - 1, index, index + 1].compactMap { i in
                    segmente.indices.contains(i) ? segmente[i] : nil
                }
                let spueleNah = imUmfeld.contains { nachbar in
                    nachbar.alleAusstattungen.contains { if case .spuelbecken = $0 { return true }; return false }
                }
                if !spueleNah {
                    hints.append(RegelHinweis(regelID: "muell-nahe-spuele", schwere: .hint,
                                                 text: "Müll-Auszug ohne Spülen-Nähe — üblich ist unter/neben der Spüle.",
                                                 zonenID: zone.id, segmentID: segment.id))
                }
            }
        }
        return hints
    }

    static func waermeschubladeUnterBackofen(_ draft: KonfigEntwurf) -> [RegelHinweis] {
        var hints: [RegelHinweis] = []
        for zone in draft.zonen {
            for segment in zone.segmente {
                let faecher = segment.faecher
                for (index, fach) in faecher.enumerated() {
                    guard case .geraet(let slot) = fach.ausstattung,
                          slot.kategorie == .waermeschublade else { continue }

                    let darueber = faecher.indices.contains(index + 1) ? faecher[index + 1] : nil
                    let backofenDarueber: Bool = {
                        guard let darueber, case .geraet(let oben) = darueber.ausstattung else { return false }
                        return oben.kategorie == .backofen
                    }()
                    if !backofenDarueber {
                        hints.append(RegelHinweis(regelID: "waerme-unter-backofen", schwere: .hint,
                                                     text: "Wärmeschublade ohne Backofen direkt darüber — üblich ist der Stapel Backofen über Wärmeschublade.",
                                                     zonenID: zone.id, segmentID: segment.id))
                    }
                }
            }
        }
        return hints
    }

    static func kochfeldBrauchtDunstabzug(_ draft: KonfigEntwurf) -> [RegelHinweis] {
        let alleSlots = draft.geraeteSlots
        let hatKochfeld = alleSlots.contains { $0.kategorie == .kochfeld }
        let hatDunstabzug = alleSlots.contains { $0.kategorie == .dunstabzug }
        guard hatKochfeld, !hatDunstabzug else { return [] }
        return [RegelHinweis(regelID: "kochfeld-dunstabzug", schwere: .hint,
                             text: "Kochfeld ohne Dunstabzug im Entwurf — Muldenlüfter oder Haube ergänzen?")]
    }

    static func durchgangInsel(_ draft: KonfigEntwurf) -> [RegelHinweis] {
        var hints: [RegelHinweis] = []
        let inseln = draft.zonen.filter { if case .insel = $0.typ { return true }; return false }
        let andere = draft.zonen.filter { if case .insel = $0.typ { return false }; return true }
        for insel in inseln {
            guard let inselPos = insel.position else { continue }
            for zone in andere {
                guard let zonePos = zone.position else { continue }

                guard insel.position?.rotationGrad == 0, zonePos.rotationGrad == 0 else { continue }
                let inselVorderkante = inselPos.yMM
                let zonenVorderkante = zonePos.yMM + zone.tiefeMM
                let spacing = inselVorderkante - zonenVorderkante
                guard spacing > 0 else { continue }
                if spacing < StudioMasse.durchgangHartMM {
                    hints.append(RegelHinweis(regelID: "durchgang-insel", schwere: .warnung,
                                                 text: "Durchgang \(zone.displayName) ↔ \(insel.displayName): \(spacing) mm — unter der harten Grenze \(StudioMasse.durchgangHartMM) mm.",
                                                 zonenID: insel.id))
                } else if spacing < StudioMasse.durchgangMinMM {
                    hints.append(RegelHinweis(regelID: "durchgang-insel", schwere: .hint,
                                                 text: "Durchgang \(zone.displayName) ↔ \(insel.displayName): \(spacing) mm — Studio-Standard ist ≥ \(StudioMasse.durchgangMinMM) mm.",
                                                 zonenID: insel.id))
                }
            }
        }
        return hints
    }

    static func zonePasstInRaum(_ draft: KonfigEntwurf) -> [RegelHinweis] {
        guard case .freieMasse(let width, let depth, _) = draft.raumBezug else { return [] }
        let maxWand = max(width, depth)
        var hints: [RegelHinweis] = []
        for zone in draft.zonen where zone.breiteGesamtMM > maxWand {
            hints.append(RegelHinweis(regelID: "zone-passt-in-raum", schwere: .warnung,
                                         text: "\(zone.displayName) ist \(zone.breiteGesamtMM) mm breit — länger als die längste Raumwand (\(maxWand) mm).",
                                         zonenID: zone.id))
        }
        return hints
    }

    static func spueleBreite(_ draft: KonfigEntwurf) -> [RegelHinweis] {
        var hints: [RegelHinweis] = []
        for zone in draft.zonen {
            for segment in zone.segmente {
                let hatSpuele = segment.alleAusstattungen.contains {
                    if case .spuelbecken = $0 { return true }
                    return false
                }
                if hatSpuele && segment.widthMm < 450 {
                    hints.append(RegelHinweis(regelID: "spuele-breite", schwere: .hint,
                                                 text: "Spülen-Korpus nur \(segment.widthMm) mm — unter 450 mm wird ein Becken eng.",
                                                 zonenID: zone.id, segmentID: segment.id))
                }
            }
        }
        return hints
    }
}

public enum KonfigRegelwerk {
    public static let alle: [KonfigRegel] = [
        KonfigRegel(id: "gs-neben-spuele", title: "GS neben Spüle", source: .annahme,
                    pruefe: { KonfigRegelLogik.gsNebenSpuele($0) }),
        KonfigRegel(id: "muell-nahe-spuele", title: "Müll in Spülen-Nähe", source: .annahme,
                    pruefe: { KonfigRegelLogik.muellNaheSpuele($0) }),
        KonfigRegel(id: "waerme-unter-backofen", title: "Wärmeschublade unter Backofen", source: .belegt,
                    pruefe: { KonfigRegelLogik.waermeschubladeUnterBackofen($0) }),
        KonfigRegel(id: "kochfeld-dunstabzug", title: "Kochfeld braucht Dunstabzug", source: .annahme,
                    pruefe: { KonfigRegelLogik.kochfeldBrauchtDunstabzug($0) }),
        KonfigRegel(id: "durchgang-insel", title: "Durchgang Insel ≥ 1000 mm", source: .annahme,
                    pruefe: { KonfigRegelLogik.durchgangInsel($0) }),
        KonfigRegel(id: "zone-passt-in-raum", title: "Zone passt in den Raum", source: .belegt,
                    pruefe: { KonfigRegelLogik.zonePasstInRaum($0) }),
        KonfigRegel(id: "spuele-breite", title: "Spülen-Korpus ≥ 450 mm", source: .annahme,
                    pruefe: { KonfigRegelLogik.spueleBreite($0) })
    ]

    public static func pruefe(_ draft: KonfigEntwurf) -> [RegelHinweis] {
        alle.flatMap { $0.pruefe(draft) }
            .sorted { lhs, rhs in
                if lhs.schwere != rhs.schwere { return lhs.schwere == .warnung }
                return lhs.regelID < rhs.regelID
            }
    }

    public static var offeneAnnahmen: [KonfigRegel] { alle.filter { $0.source == .annahme } }
}
