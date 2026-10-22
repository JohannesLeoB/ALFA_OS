---
name: spec-format
description: Format und Schreibregeln der Spec-Dateien im Gedächtnis; jede Änderung schreibt die Zeile neu, nichts wird angehängt
metadata:
  type: reference
---


Warum: Johannes 21.10.: Wörtliche Zitate sind „wie ein spiegelkabinett“; gebraucht werden „specs udn Ziele“, die „wie strömungen vorgehen sich vertiefen“, analytisch aufgearbeitet und triagiert. Die Zitate bleiben in den Transkripten (Archiv). Das Gedächtnis hält die Spec.

## Aufbau einer Spec-Datei

```
---
name: spec-<bereich>
description: <ein Satz: was der Bereich ist und wie weit er ist>
metadata:
  type: project
---

# <Bereich> · Spec (Stand 21.10.)

## Ziel
1–3 Sätze: wozu der Bereich da ist, aus Johannes' Sicht. Kein Zitat, eine Aussage.

## Richtung
2–5 Punkte: wohin er sich später vertieft (seine Strömung), ausdrücklich „später“.

## Funktionen
- **<KÜRZEL>-F01 <Name>**: Soll: <prüfbarer Satz: was der Nutzer tun kann / was passiert>. Ist: <`Datei:Zeile`> oder „fehlt“. Status: <orange|rot|offen|lücke>. Quelle: <Master `Datei:Zeile` · J <TT.MM.> <Sitzung kurz> · Bestand `Pfad`>.

## Regeln
- **<KÜRZEL>-R01**: <prüfbare Regel, z. B. Besitz, Grenzen, Reihenfolge, was nie passiert>. Quelle: …

## Lücken
- **<KÜRZEL>-L01**: <was fehlt>, <wer liefert: Design | Johannes>. Beleg: <Suchweg, Datei:Zeile>.

## Offen bei Johannes
- nur echte Produktentscheidungen, je ein Satz.
```

## Regeln für den Schreiber
- Jeder Satz ist prüfbar (man kann am Code, am Master oder an Johannes' Wort sehen, ob er stimmt). Keine Stimmung, keine Wiederholung von AGENTS.md.
- **Status:**
  - „grün“ gibt es nicht ohne Johannes' Abnahme; heute hat nichts sie.
  - „orange“ = gebaut, nicht abgenommen.
  - „rot“ = gebaut, aber falsch oder tut nur so.
  - „offen“ = nicht gebaut, Vorgabe da.
  - „lücke“ = Vorgabe fehlt.
- **Ist** nur mit eigenem Beleg: Datei:Zeile selbst gelesen oder per grep gefunden. Ohne Beleg: „ungeprüft“.
- **Quelle** kurz: Master-Zeile, Datum für Johannes' Wort (J TT.MM.), Bestandspfad. Keine Zitate: Entscheidungen stehen als Aussage im Funktionsbaum (Funktion, Soll, Ist, Status), das Transkript trägt den Wortlaut.
- **Stil**: Funktionsbäume und kurze Sätze, keine Erzählung, keine Wiederholung zwischen `stand.md` und Spec; Lücken und Offenes stehen nur in der Spec des Bereichs, `stand.md` verweist darauf.
- Johannes' Wort geht vor Master, das jüngere vor dem älteren (AGENTS.md §2). Was nur Design, ein Agent oder ein altes Dokument sagt, ist kein Soll; höchstens Lücke oder Frage.
- Was eine andere Spec-Datei trägt: nur Verweis (`siehe spec-hub HUB-F03`), nicht doppelt.
- Keine Zahl ohne Beleg. Kein „myk“ in Kürzeln oder Namen.
- Länge: so kurz wie möglich, so vollständig wie nötig. Richtwert 80–200 Zeilen je Bereich.
- Kürzel: ZIEL, HUELLE, MAIL, HUB, PROJ, HEUTE, KAT, KORB, SPAET, ARBEIT, ARCH.
