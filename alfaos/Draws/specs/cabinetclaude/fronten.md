# Fronten

Pack: Dicke 18, Fuge 2 (Daten). Front-Liste je Schrank von oben nach unten (gebaut, Cabinets.swift:159).

| Typ | Varianten | Regel | Status |
|---|---|---|---|
| Tür | links, rechts, Paar | Paar ab Breite 800 (pairFrom); Aufschlag 100 Grad | gebaut (:196, :339) |
| Schublade | Teilung low/mid/high, Anzahl 1-4 | Anteile 0.2/0.3/0.5; Mindesthöhe 100 | gebaut (:165) |
| Klappe | Hochklappe 90 Grad | Achse x/y nach Zeilendrehung | gebaut (:330) |
| Klappe Schwenk/Falt | Schwenkklappe, Faltklappe | | offen |
| Glas | Glastür | Material glas | gebaut |
| Rahmenfront | Rahmen + Füllung | zwei Teile | offen |
| Gerät | oven, dishwasher, fridge | eigene Höhe, Name, Material | gebaut |
| Gerät | microwave, steamer | | offen |
| Einlass | hob, sink | Part in Platte, keine Front | gebaut |
| Offen | open | keine Front, Korpus hohl | gebaut |

## Teilung
- Feste Höhe (front.height oder Gerätehöhe) zuerst, Rest gleichmäßig auf Flex-Fronten.
- Schubladenblock: nutzbare Höhe = Spanne minus n x Fuge, verteilt nach Anteil.
- Summe fester Höhen größer als Schrankhöhe = Fehler split (gebaut, :182).
- Auszugsweg = Tiefe minus 150 (reserve).

## Griff
| Variante | Modell | Status |
|---|---|---|
| Griff (Bügel/Stange) | Part an Front | offen |
| Knopf | Part | offen |
| Griffleiste | Part, durchlaufend | offen |
| grifflos mit Nut | Nut im Frontrand, Fuge vergrößert | offen |
| Push-to-open | Metadatum, Fuge unverändert | offen |
Heute keine Griffe im Generator; Griffart als Feld je Front und je Küche vorsehen (K-02).

## Fuge
Front = Schrankbreite minus Fuge, Fuge halb je Seite (gebaut). Paar: Mittelfuge = Fuge.
Frontdicke vor Korpus, Fläche bündig zur Vorderkante (vf = hinten - Tiefe - Dicke).
