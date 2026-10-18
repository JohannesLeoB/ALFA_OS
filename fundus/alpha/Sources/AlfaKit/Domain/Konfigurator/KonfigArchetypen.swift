import Foundation

public struct KonfigArchetyp: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var beschreibung: String

    public var baue: @Sendable () -> [KonfigZone]

    public init(id: String, name: String, beschreibung: String,
                baue: @escaping @Sendable () -> [KonfigZone]) {
        self.id = id
        self.name = name
        self.beschreibung = beschreibung
        self.baue = baue
    }
}

public enum KonfigArchetypen {
    static func hochschrankwandGeraeteblock() -> KonfigZone {
        let vorrat1 = KonfigSegment(widthMm: 600, faecher: [
            KonfigFach(heightMm: 800, ausstattung: .schubkaesten(count: 2, material: .legrabox)),
            KonfigFach(heightMm: 1260, ausstattung: .tuerMitFachboeden),
            KonfigFach(heightMm: 560, ausstattung: .fachboeden)
        ])
        let geraeteSaeule = KonfigSegment(widthMm: 600, faecher: [
            KonfigFach(heightMm: 800, ausstattung: .geraet(GeraetSlot(kategorie: .waermeschublade))),
            KonfigFach(heightMm: 600, ausstattung: .geraet(GeraetSlot(kategorie: .backofen))),
            KonfigFach(heightMm: 660, ausstattung: .geraet(GeraetSlot(kategorie: .kaffeevollautomat))),
            KonfigFach(heightMm: 560, ausstattung: .fachboeden)
        ])
        let kuehl = KonfigSegment(widthMm: 759, faecher: [
            KonfigFach(heightMm: 2060, ausstattung: .geraet(GeraetSlot(kategorie: .kuehlGefrier))),
            KonfigFach(heightMm: 560, ausstattung: .fachboeden)
        ])
        let breitMitNische = KonfigSegment(widthMm: 1200, faecher: [
            KonfigFach(heightMm: 800, ausstattung: .schubkaesten(count: 2, material: .legrabox)),
            KonfigFach(heightMm: 1260, ausstattung: .offenesRegal),
            KonfigFach(heightMm: 560, ausstattung: .fachboeden)
        ])
        return KonfigZone(typ: .hochschrankwand, name: "Hochschränke",
                          tiefeMM: 650, korpusHoeheMM: 2620, sockelMM: 80,
                          hoehenbaenderMM: [800, 1260, 560],
                          segmente: [vorrat1, geraeteSaeule, kuehl, breitMitNische])
    }

    static func spuelenzeile() -> KonfigZone {
        KonfigZone(typ: .rowItem, name: "Spülenzeile",
                   tiefeMM: 635, korpusHoeheMM: 780, sockelMM: 80,
                   segmente: [
                    KonfigSegment(widthMm: 600, ausstattung: .geraet(GeraetSlot(kategorie: .geschirrspueler))),
                    KonfigSegment(widthMm: 600, ausstattung: .spuelbecken),
                    KonfigSegment(widthMm: 600, ausstattung: .muellAuszug),
                    KonfigSegment(widthMm: 600, ausstattung: .schubkaesten(count: 3, material: .legrabox)),
                    KonfigSegment(widthMm: 450, ausstattung: .schubkaesten(count: 3, material: .legrabox))
                   ])
    }

    static func kochzeile() -> KonfigZone {
        KonfigZone(typ: .rowItem, name: "Kochzeile",
                   tiefeMM: 635, korpusHoeheMM: 780, sockelMM: 80,
                   segmente: [
                    KonfigSegment(widthMm: 600, ausstattung: .schubkaesten(count: 3, material: .legrabox)),
                    KonfigSegment(widthMm: 600, faecher: [
                        KonfigFach(ausstattung: .geraet(GeraetSlot(kategorie: .backofen)))
                    ]),
                    KonfigSegment(widthMm: 600, ausstattung: .schubkaesten(count: 3, material: .legrabox))
                   ])
    }

    static func inselMitTresen() -> KonfigZone {
        KonfigZone(typ: .insel, name: "Insel",
                   tiefeMM: 1160, korpusHoeheMM: 780, sockelMM: 80,
                   segmente: [
                    KonfigSegment(widthMm: 825, ausstattung: .schubkaesten(count: 2, material: .legrabox)),
                    KonfigSegment(widthMm: 825, ausstattung: .schubkaesten(count: 2, material: .legrabox))
                   ],
                   ueberstandMM: 300)
    }

    static func inselKompakt() -> KonfigZone {
        KonfigZone(typ: .insel, name: "Insel",
                   tiefeMM: 950, korpusHoeheMM: 780, sockelMM: 80,
                   segmente: [
                    KonfigSegment(widthMm: 725, ausstattung: .tuerMitFachboeden),
                    KonfigSegment(widthMm: 725, ausstattung: .schubkaesten(count: 3, material: .holzMassiv)),
                    KonfigSegment(widthMm: 725, ausstattung: .schubkaesten(count: 3, material: .holzMassiv)),
                    KonfigSegment(widthMm: 725, ausstattung: .tuerMitFachboeden)
                   ])
    }

    static func wandzeile() -> KonfigZone {
        KonfigZone(typ: .wandzeile, name: "Wandschränke",
                   tiefeMM: 350, korpusHoeheMM: 800, sockelMM: 0,
                   segmente: [
                    KonfigSegment(widthMm: 600, ausstattung: .tuerMitFachboeden),
                    KonfigSegment(widthMm: 600, ausstattung: .tuerMitFachboeden),
                    KonfigSegment(widthMm: 600, ausstattung: .offenesRegal)
                   ])
    }

    static func sideboard() -> KonfigZone {
        KonfigZone(typ: .frei("Sideboard"), name: "Sideboard",
                   tiefeMM: 450, korpusHoeheMM: 700, sockelMM: 60,
                   segmente: [
                    KonfigSegment(widthMm: 800, ausstattung: .tuerMitFachboeden),
                    KonfigSegment(widthMm: 800, ausstattung: .schubkaesten(count: 2, material: .legrabox)),
                    KonfigSegment(widthMm: 800, ausstattung: .tuerMitFachboeden)
                   ])
    }

    static func renovationFrontsIsland() -> [KonfigZone] {
        let hochschrank = KonfigZone(typ: .hochschrankwand, name: "Hochschränke (Bestand, neue Fronten)",
                                     tiefeMM: 650, korpusHoeheMM: 2620, sockelMM: 80,
                                     hoehenbaenderMM: [2060, 560],
                                     segmente: [
                                        KonfigSegment(widthMm: 600, faecher: [
                                            KonfigFach(heightMm: 2060, ausstattung: .tuerMitFachboeden),
                                            KonfigFach(heightMm: 560, ausstattung: .blende)
                                        ]),
                                        KonfigSegment(widthMm: 600, faecher: [
                                            KonfigFach(heightMm: 2060, ausstattung: .tuerMitFachboeden),
                                            KonfigFach(heightMm: 560, ausstattung: .blende)
                                        ])
                                     ])
        let insel = KonfigZone(typ: .insel, name: "Insel (neue Korpen unter Bestands-Platte)",
                               tiefeMM: 1200, korpusHoeheMM: 780, sockelMM: 80,
                               segmente: [
                                KonfigSegment(widthMm: 725, ausstattung: .tuerMitFachboeden),
                                KonfigSegment(widthMm: 725, ausstattung: .schubkaesten(count: 3, material: .holzMassiv)),
                                KonfigSegment(widthMm: 725, ausstattung: .schubkaesten(count: 3, material: .holzMassiv)),
                                KonfigSegment(widthMm: 725, ausstattung: .tuerMitFachboeden)
                               ])
        return [hochschrank, insel]
    }

    public static let alle: [KonfigArchetyp] = [
        KonfigArchetyp(id: "hochschrankwand-geraeteblock",
                       name: "Hochschrankwand mit Geräteblock",
                       beschreibung: "4 Segmente, 3 Bänder — Gerätesäule, Einbau-Kühl, offene Nische",
                       baue: { [hochschrankwandGeraeteblock()] }),
        KonfigArchetyp(id: "spuelenzeile",
                       name: "Spülenzeile",
                       beschreibung: "GS · Spüle · Müll · 2× Schubkästen — die Kette verdrahtet",
                       baue: { [spuelenzeile()] }),
        KonfigArchetyp(id: "kochzeile",
                       name: "Kochzeile",
                       beschreibung: "Backofen-Unterbau zwischen Schubkasten-Korpen",
                       baue: { [kochzeile()] }),
        KonfigArchetyp(id: "insel-tresen",
                       name: "Insel mit Tresen",
                       beschreibung: "2× 825, Arbeitsplatten-Überstand 300",
                       baue: { [inselMitTresen()] }),
        KonfigArchetyp(id: "insel-kompakt",
                       name: "Insel kompakt",
                       beschreibung: "4 Korpen gleicher Breite, Holz-Schubkästen mittig",
                       baue: { [inselKompakt()] }),
        KonfigArchetyp(id: "wandzeile",
                       name: "Wandschränke",
                       beschreibung: "Hängend, 3 Segmente, eines offen",
                       baue: { [wandzeile()] }),
        KonfigArchetyp(id: "sideboard",
                       name: "Sideboard",
                       beschreibung: "Freies Möbel, 3 Segmente",
                       baue: { [sideboard()] }),
        KonfigArchetyp(id: "renovation-fronts-island",
                       name: "Renovierung: Fronten + Insel-Korpen",
                       beschreibung: "Bestand behalten, neue Fronten + 4 Insel-Korpen",
                       baue: { renovationFrontsIsland() })
    ]

    public static func archetyp(id: String) -> KonfigArchetyp? {
        alle.first { $0.id == id }
    }
}
