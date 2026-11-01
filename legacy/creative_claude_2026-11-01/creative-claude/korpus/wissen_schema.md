# Wissens-Schema – Korpusbibliothek & Küchenwissen

Ziel: Aus realen Studio-Plänen lernen, wie das Studio Küchen plant. Genauigkeit **grob** (Hauptmaße, Muster, Häufigkeiten); Feinheiten tunen später Nutzer. Reale Pläne enthalten menschliche Fehler – notieren, nicht korrigieren.
Kein Raster unterstellen: jede Küche ist mm-genau für einen realen Raum geplant. Gesucht sind Bereiche und Häufungen, keine Normwerte.
Keine Namen (Personen, Kunden, Studio, Lieferanten-/Produktnamen nur als Kategorie, z. B. „Edelstahl-Front“, „Kochendwasser-Armatur“), keine Adressen. Plankopf, Stempel (z. B. „Vorabzug“), Musterdaten-Felder sind KEINE Trainingsdaten.
Beleg je Aussage: `T<Nr> S.<Seite>` (Template-Nummer, Seite).

## Ausgabe: ein JSON-Objekt

```json
{
  "runde": "A|B|C", "gruppe": "G1..G6",
  "gelesen": [{"template": "T01", "seiten": "6/6", "art": "Layout|Moodboard|Präsentation", "inhalt": "1 Satz: was zeigt das Dokument"}],

  "kuechen": [
    {"id": "T01-K1", "belege": ["T01 S.2"],
     "form": "zeile|zweizeilig|L|U|insel|halbinsel|nische|sonstiges",
     "raum": {"wandbezug": "…", "fenster_tuer": "…", "abstand_wand_decke": "…", "freiraum_gang_mm": null},
     "laengen_mm": [], "hoehen": {"sockel": null, "ok_ap": null, "ap_d": null, "oberschrank_uk": null, "hochschrank_h": null, "decke": null},
     "tiefen": {"unterschrank": null, "hochschrank": null, "oberschrank": null, "insel": null},
     "schraenke": [{"pos": 1, "kategorie": "unterschrank|hochschrank|oberschrank|insel|nischenregal|sonstiges", "typ": "Katalog-ID oder NEU:<name>", "b": null, "h": null, "t": null, "fronten": "z. B. 3 Auszüge 1:1:2", "innen": "…", "geraet": null}],
     "geraete_reihenfolge": "z. B. KS – Spüle – GSP – Kochfeld (links→rechts)",
     "abstaende": {"spuele_kochfeld_mm": null, "kochfeld_wand_mm": null, "gsp_neben_spuele": null, "ks_spuele_mm": null},
     "anschluesse": {"passblenden": "…", "fuellstuecke": "…", "stellseiten": "…", "wand_decken_anschluss": "…", "sockel": "…", "eckloesung": "…"},
     "griffe": "griffmulde|griffleiste|push|stangengriff|knopf|integriert|…",
     "material_farbe": "…",
     "plan_widersprueche": []}
  ],

  "wissen": {
    "griffarten": [{"art": "…", "wo": "…", "haeufigkeit": 0, "belege": []}],
    "layouts_anordnungen": [{"muster": "…", "belege": []}],
    "innenausstattung": [{"element": "…", "kontext": "…", "belege": []}],
    "raumstellung": [{"regel_oder_muster": "…", "belege": []}],
    "raster_masse": [{"beobachtung": "z. B. Breiten 450/600/… oder frei", "belege": []}],
    "hoehenbereiche": [{"groesse": "sockel|ok_ap|oberschrank_uk|hochschrank|…", "werte": [], "belege": []}],
    "geraete_beziehungen": [{"beziehung": "z. B. GSP direkt neben Spüle", "belege": []}],
    "laufwege_ergonomie": [{"beobachtung": "…", "masse": [], "belege": []}],
    "anschluesse_blenden_fuellstuecke": [{"detail": "…", "masse": [], "belege": []}],
    "stil": [{"merkmal": "Material, Farbe, Formsprache, wiederkehrende Details", "belege": []}],
    "zeichenstil": [{"merkmal": "Blattarten, Ansichten, Bemaßungsweise, Legenden", "belege": []}],
    "moodboard_praesentation": [{"merkmal": "Seitentypen, Aufbau, gezeigte Inhalte", "belege": []}],
    "neue_katalogtypen": [{"vorschlag": "…", "belege": []}],
    "offen": []
  }
}
```
Leere Kategorien als `[]` lassen. Fertig = jede Seite jedes zugewiesenen Templates gelesen und `gelesen` vollständig.
