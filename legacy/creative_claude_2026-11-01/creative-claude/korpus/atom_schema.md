# Atom-Schema – Küchenwissen

Ein **Atom** ist genau eine prüfbare Aussage. Kein Atom enthält „und“ über zwei Sachverhalte. Keine Namen (Personen, Kunden, Studio, Marken).

## Format: eine JSON-Zeile je Atom (atome_vN.jsonl)

```json
{"id":"GER-001","art":"regel","bereich":"geraete",
 "wenn":"Küche hat Spüle und GSP",
 "dann":"GSP steht direkt neben der Spüle (links oder rechts)",
 "wert":null,"einheit":null,
 "belege":["T04","T17","T18"],
 "treffer":0,"gegen":0,"nicht_pruefbar":0,
 "staerke":"fest|haeufig|selten",
 "quelle":"konsens_G1 geraete_beziehungen",
 "abhaengig_von":[],"ausnahmen":[]}
```

## Felder
- **id**: Präfix je Bereich + laufende Nummer. Präfixe: `MAS` Maß/Bereich · `BRE` Breite · `FRO` Front/Aufteilung · `GRI` Griff · `INN` Innenausstattung · `GER` Gerätebeziehung · `LAY` Layout · `RAU` Raumstellung · `ANS` Anschluss/Blende/Füllstück · `STI` Stil · `ZEI` Zeichenstil · `PRA` Präsentation.
- **art**: `regel` (wenn→dann, prüfbar an einer Küche) · `mass` (Startwert + Bereich) · `muster` (häufige Lösung, Alternative möglich) · `stil` (Profilwert).
- **wenn / dann**: kurz, eindeutig, in Planbegriffen. `mass`: dann = „Größe = Startwert“, `wert` = {"start":…, "min":…, "max":…}.
- **belege**: Template-IDs (T01…T41), in denen die Aussage gilt.
- **treffer / gegen / nicht_pruefbar**: Zähler der Lernschleife (Start 0).
- **staerke**: aus Konsens übernehmen; fest = 3/3 in ≥ 2 Gruppen, haeufig = 2/3 oder eine Gruppe, selten = Einzelfall.
- **ausnahmen**: bekannte Gegenbeispiele mit Template-ID.

## Testfall (je Küche, für die Lernschleife)

```json
{"kueche":"T40-K1","form":"insel","bekannt":{…},"verdeckt":{…},
 "vorhersagen":[{"atom":"GER-001","vorhersage":"…","ist":"…","ergebnis":"treffer|gegen|nicht_pruefbar"}],
 "neue_atome":[…],"luecken":["was die Atome nicht vorhersagen konnten"]}
```
