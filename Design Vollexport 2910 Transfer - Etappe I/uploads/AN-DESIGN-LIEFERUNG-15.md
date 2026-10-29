# An Design: Wünsche für Lieferung 15

Stand 2026-10-17, Code (Chef). Gegen Lieferung 14 geprüft, `gestaltung/alfa-interface/design.json`. Gebaut aus dem Quelltext des Entwurfs, nie gegen ein Bild.

Format jeder Antwort: Tokenname, Wert hell und dunkel, Quelle im Entwurf (Datei:Zeile). Fehlt ein Wert, bitte "entfällt" schreiben, damit Code ihn löscht.

## A · Werte in der App ohne Quelle im Tokenbogen (blockiert Aufräumen)

Diese Zahlen stehen heute in `alfaos/App/Resources/shell.json`. Der Tokenbogen kennt sie nicht (Suche in `design.json` ohne Treffer).

| Nr | Wert heute | Wo benutzt | Frage an Design |
|---|---|---|---|
| A1 | linkes Minimum 224 | `ShellMetrics.swift:99` | Steht im Entwurf (`alfa-shell.js:5`, `min: [224, 280, 280]`), aber nicht im Bogen. Bitte als Token `laneMinimumLeft` aufnehmen. |
| A2 | Assistent-Breite 360 | `ShellView.swift:62`, `AssistantView.swift:39` | Im Entwurf nicht gefunden. Breite oder entfällt? |
| A3 | Blob-Wurf 0,12 | `BlobPlacement.swift:65` | Im Entwurf nicht gefunden. Wert oder entfällt? |
| A4 | Schatten-Weichzeichner-Faktor 0,5 | `Theme.swift:109` | Im Entwurf nicht gefunden. Bitte Schattenwerte so liefern, dass kein Faktor nötig ist. |
| A5 | Kopf rechts 10 | `LaneView.swift:61` | Im Entwurf: Abstand rechts im Bahnkopf? |
| A6 | Menü: Feld 10, Gruppe 10, Zeile vorn 18, Zeile hinten 10 | `BlobMenuView.swift:80,98,149,150` | Im Entwurf-Menü sind 12 und 8 zu sehen, nicht 10 und 18. Bitte die Abstände des Blob-Menüs als Tokens. |

## B · Mail-Spalte: im Entwurf, in der App noch offen

| Nr | Thema | Stand in der App | Frage an Design |
|---|---|---|---|
| B1 | Übersicht, Ordner-Modus | fehlt (`ovMode "folder"` im Entwurf) | Was bedeutet "Ordner · n": Kacheln des Ordners statt des Stapels? Auswahl und Beenden? |
| B2 | Übersicht-Knopf | liegt im Kartenkopf (Code-Wahl) | Entwurf legt ihn in die Spaltenleiste (`HB`, `fanB`). Soll der Knopf wirklich dorthin, auch in anderen Bereichen? |
| B3 | Antworten, Weiterleiten | Modell hat keine Antwort-Aktion | Bitte alle Aktionen von Kachel, Fuß und "Mehr" als Liste: Name, Symbol, Wirkung, Zustand (aktiv, gesperrt). |
| B4 | Drucken und PDF | fehlt | Gehört es zum Fuß? Wenn ja, in welcher Gruppe? |
| B5 | "Verschieben nach …" | "später" laut Rückgabe | Wann kommt der Entwurf? |
| B6 | Mehrfachauswahl | "Design entwirft sie als Nächstes" (Rückgabe, 9) | Bitte Entwurf. |

## C · Namen

- C1 `accounts` im Code, aber zwei Entwurfswörter: `konten` und `mailkonten` (`gestaltung/nomenclature.json`). Zwei Dinge unter einem Namen. Bitte entscheiden, welches welcher Bereich ist.

## D · Später laut Rückgabe, bitte Reihenfolge nennen

Glas für macOS 26 (Punkt 19) · Dienste, Mitteilungen, Team, Impressum (25, 31, 32, 33) · Einstellungskacheln und Kontextmenü, falls über Lieferung 14 hinaus neu.

## E · Von Johannes, nicht von Design

Geist-Schriftdateien · Impressum-Daten.

## Was Code von Design annimmt

Fläche flach, Lack bleibt im Code hinter einem Schalter, Glas später. Was der Entwurf nicht zeigt, baut Code nicht.
