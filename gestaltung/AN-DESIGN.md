# ALFA · Code an Design: eine Lieferung (Stand 16.10.2026)

Code `8978f57`. Gelesen: Lieferung „Arbeitswelt ALFA Interface Zugang (13)“ vom 16.10. 02:05. Schon eingebaut: `TOKENBOGEN.json` ganz (als `design.json`), Ruhebreite 280, Farben der Hülle, Zeilen, Abstände, Radien und Schrift in Mail-Konten, Mail-Liste und Einstellungen.
Format: eine Datei je Block, UTF-8-JSON, Zahlen ohne Einheit (px, ms), Farben `#rrggbb` oder `rgba(r,g,b,a)`, Namen englisch lowerCamelCase. Wo keine Antwort kommt, baut Code den **Standard**.

## A. Blockiert den Bau (bitte zuerst)

| Nr | Was | Datei, Format | Standard |
|---|---|---|---|
| A1 | Widersprüche in der Lieferung | `decisions.json`: `[{"item":"A1a","answer":"280"}]` | siehe Zeile |
| A1a | Mittelbahn-Minimum: README und `K.center` 480, `AREA.min` 280 | Zahl | 280 |
| A1b | Griff: sichtbar 1 (Entwurf) oder 4 (Code); Trefferfläche | `{"visible":1,"hit":12}` | 1 und 12 |
| A1c | Symbolstrich 1,3 (README) oder 1,15 (Arbeitsstand) | Zahl | 1,3 |
| A1d | Symbolknopf 28 rund oder 26 eckig | `{"size":28,"shape":"round"}` | 28 rund |
| A1e | Blob-Auge 4 × 8, Abstand 4 („Vorschlag“) bestätigen | ja/nein | ja |
| A1f | Kleinstes Fenster (Entwurf 640 × 480, Code 960 × 600) | `{"w":640,"h":480}` | 640 × 480 |
| A2 | Fehlender Bahn-Hintergrund dunkel (`--c-lane` #141414 nur in `alfa-theme.css`) | in `TOKENBOGEN.json` als `color.dark.lane` und `color.light.lane` | #141414 / #ffffff |
| A3 | Fehler im Bogen: README Karte 12, JSON `radius.card` 20; Schatten verweist auf `{color.hell.line}` (heißt `color.light.line`); `component.*` teils bloße Strings | berichtigte `TOKENBOGEN.json` | JSON gilt, Alias wird aufgelöst |
| A4 | Einstellungen als **eine** Fassung | `settings-sections.json`: `[{"id":"integrations","group":"connections","name":"Integrationen","symbol":"plug","source":"hub"}]`, `source`: `hub`, `local`, `none` (nicht bauen) | `Inhalt`-Fassung, Gruppe Mail entfällt |
| A5 | Schrift: Geist als Dateien (Light, Regular, Medium) mit Lizenz, Mono ja oder nein | `fonts/Geist-*.otf`, `LICENSE.txt` | Systemschrift, keine Mono |

## B. Für die Ansichten

| Nr | Was | Datei, Format |
|---|---|---|
| B1 | Rollen für Quarantäne (80) und mehrdeutige (29) Tokens, Liste liegt bei Code: `quarantine.json` | `token-roles.json`: `[{"code":"space-m","role":"component.laneGap"}]` oder `{"code":"palette-red-500","role":null}` (null = weg) |
| B2 | Federn für SwiftUI statt Zeiten | `motion-springs.json`: `[{"token":"stack","duration":0.52,"bounce":0.15,"reduced":"none"}]` |
| B3 | Flächen Lack, Glas, flach als Werte (Formeln in `surface` sind Ebenen ohne Namen) und Liquid Glass von macOS 26 ja oder nein | `surfaces.json`: `{"lacquer":{"light":{"fill":"#ffffff","stroke":{"width":1,"color":"#e8e8e8"},"shadow":[{"x":0,"y":1,"blur":2,"spread":0,"color":"rgba(0,0,0,0.2)"}]},"dark":{}},"glass":{},"flat":{}}` |
| B4 | Zustandswörter: Entwurf `stored`, `unreadable`, Code `signedIn`, `keychainUnreadable`; fehlende Mail-Zustände `loadingMore`, `noFilterMatch`, `signInExpired`, `saving`, `queuedInOutbox` | `states.json`: `[{"design":"stored","code":"signedIn","word":"settings.state.signedIn"}]` |
| B5 | 80 von 130 Texten | `texts.json`: `{"mail.list.loadingMore":"Lädt mehr …"}` (Schlüssel wie in `alfaos/App/Localizable.xcstrings`) |
| B6 | Abläufe ohne Spezifikation: Rückgängig (Archiv, Papierkorb, Trennen; Toast 4000 ms), Mehrfachauswahl großer Postfächer, Signatur anlegen, bearbeiten, löschen, Bestätigen-Pille (Halten 500 ms) | `flows.json`: `[{"id":"undo","states":["idle","asking","running","done"],"events":["press","timeout"],"transitions":[["idle","press","asking"]],"durationMs":{"hold":500,"toast":4000}}]` |
| B7 | Zielwahl „Verschieben nach …“ | `move-targets.json`: `{"source":"folders","include":["labels","system"],"exclude":["sent","spam"]}` |
| B8 | Kartenstapel: Tiefe, Versatz, Kopf und Fuß als Maße | `stack.json`: `{"offsetX":0,"offsetY":8,"scale":0.97,"head":44,"foot":44}` |

## C. Inhalte und Dienste

| Nr | Was | Datei, Format |
|---|---|---|
| C1 | Dienste (Ziel 30 bis 50, geliefert 10) | `services.json`: `[{"id":"clickup","name":"ClickUp","group":"personal","access":"key","fields":[{"id":"token","label":"Zugriffsschlüssel","secret":true}],"areas":[{"id":"tasks","name":"Aufgaben","interval":"manual"}],"logo":"logos/clickup.svg"}]`, `access`: `signIn`, `key`, `form` |
| C2 | Logos je Dienst, einfarbig; offen: „Happa Happa“, monday | `logos/<id>.svg` |
| C3 | Dienstzustand „kommt aus Integration und Mitteilungen des Users“: welche Optionen je Dienst | in `services.json` je Dienst `"notices":["newMail","error"]` |
| C4 | Hub als Startansicht der Einstellungen; mehrere Mail-Konten gestapelt oder Wähler | ja/nein, Standard: Hub, gestapelt |
| C5 | Impressum (Anschrift, Telefon, USt-IdNr.) | `imprint.json`: `{"name":"","address":"","email":"","phone":"","vat":""}`, leer lassen, wo es nichts gibt |
| C6 | Alles ohne reale Quelle als „nicht bauen“ markieren (Tastenkürzel 13, Version 0.4.2, Backups, Tagebuch, Werkstattfaktoren, Schlüssel-Inventar 9) | in `settings-sections.json`: `"source":"none"` |

## D. Wünsche, später

- Farbleiter (Johannes 13.10.: „noch keine“): Tokenbogen bleibt grau mit Signalrot, bis sie kommt.
- `data-teil` → `data-part` (Johannes: „alles strikt englisch“).
- Mehrfachauswahl, Fächern (Carousel oder Raster als Vorschau), Kartenturm 8a/8b mit Material.
- Lieferung künftig mit den Dateinamen oben statt Fließtext, dazu ein Zeitpunkt je Datei.

## Antwort von Code
Code liest die Dateien, setzt jede Zahl in `design.json` bzw. den erzeugten Konstanten, erneuert den Stempel (sichtbar in Einstellungen, System) und meldet je Zeile „gleich, geändert, offen“ zurück. Was nicht in diesen Formaten kommt, baut Code nicht.
