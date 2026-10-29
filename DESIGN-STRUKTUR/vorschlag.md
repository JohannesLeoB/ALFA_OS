# Vorschlag · Design-Struktur

Stand 29.10.2026, **Vorschlag, ungeprüft**. Die Belege stehen in `verflechtung.*`, `code-schnitt.md` und `vertrag-schnitt.md`.

## 1 · Empfehlung in einem Satz
**Modell (b), Schichten mit Schnittstellen:** ein flacher Design-Stamm mit Grundlage, Fachmodulen und Ansichten. Die Module sind über Namen und eine Modul-Liste getrennt, nicht über Ordner. Zweige gibt es nur je Arbeit, Lieferungen als Tag.

## 2 · Die zwei Modelle

| | (a) nach Bildschirmen | (b) Schichten mit Schnittstellen |
|---|---|---|
| Mappen | Mail, Einstellungen, Projekte, Werkstatt je ein Ordner oder Zweig | **Grundlage** (Tokens, Hülle, Bauteile, Bewegung, Textregeln, Werkzeuge) · **Fachmodule** (Mail, Hub/Dienste, Assistent, Projekte, Werkstatt/<Editor>) · **Ansichten** (Bögen) |
| Einstellungen und Hub | eigener Bildschirm, der alles der anderen enthält | Ansicht, die die Beiträge der Fachmodule zeigt; jedes Modul führt seine Einstellungen und Hub-Routen in seiner Modul-Liste |
| Querverweise | gehen bei jeder Änderung verloren: 11 Einstellungs- und 12 Routen-Einträge zielen auf andere Bereiche | stehen in der Verflechtungskarte; eine Änderung zeigt, welche Bereiche sie mitnimmt |
| Hülle nur einmal | jede Mappe braucht eine Kopie (dc-import nur im selben Ordner) → heute 3 Fassungen (HILFE-02) | eine Hülle am Stamm |
| An Code | je Bildschirm | wie der Code: Grundlage → `Resources/tokens.json`, `App/Components`, `App/Shell`; Module → `App/<Feature>` und `Sources/<Module>` |
| Passt zum Code | nein: Einstellungen greift in 4 Module (`App/Settings/SettingsContext.swift:1–18`) | ja, bis auf zwei Punkte (Abschnitt 3) |
| Passt zum Vertrag | Texte und Element-IDs ja; Bauteile nein (24 von 97 in mehreren Bögen) | Bauteile und Tokens ja (überwiegend gemeinsam) |

**Warum (b):**
- 45 Verflechtungen, davon 23 als Einstellung oder Route quer zu anderen Bereichen (`verflechtung.json`).
- Der Code ist schon in Schichten mit Ports geschnitten.
- Eine Hülle pro Mappe hat bereits drei verschiedene Hüllen erzeugt.

## 3 · Wo (b) vom Code abweicht
1. Der Hub ist im Code ein **Modul** (`Sources/Hub`), keine reine Ansicht. Vorschlag: Im Design ist Hub/Dienste ein Fachmodul; Einstellungen zeigt es.
2. Die Einstellungs-Abschnitte sind im Code **eine feste Liste** (`Sources/Hub/Model/SettingsSection.swift:1–26`), nicht Beiträge der Module. Ob der Code das ändert, entscheidet Johannes (Frage 4).

## 4 · Technische Grenzen

| Grenze | Stelle | Was sich für (b) ändern müsste |
|---|---|---|
| `dc-import` findet nur Dateien im selben Ordner (KALTSTART §4) | `Design Vollexport 2910 Transfer - Etappe I/ALFA Mail.dc.html:13` | nichts, solange alle Bögen am Stamm bleiben |
| Werkzeuge lesen Bögen am Stamm | `contract-build/lauf.js:17` | nichts |
| feste Bogennamen | `contract-build/lauf.js:18`, `contract-build/apply.js:37` (enthält das gelöschte „ALFA PDF“) | Namen aus der Modul-Liste lesen |
| feste Bereiche shell, mail, settings | `contract-build/lauf.js:19`, `contract-build/apply.js:38` | Bereiche aus der Modul-Liste lesen |
| Lieferschein nimmt **jeden** Bogen am Stamm auf | `contract-build/lauf.js:22`, `contract-build/check-delivery.js:17` | Werkstatt- und Projekt-Bögen kämen ungefragt in die Lieferung; Filter über die Modul-Liste |
| `t9-css.js` schreibt nur feste Token-Gruppen ins CSS | `contract-build/t9-css.js:11` | neue Modul-Gruppen in die Liste aufnehmen |
| `pruefung.js`: feste Dateilisten, Exportdatum nur bis 31.10.2026 | `lieferung-an-code/pruefung.js:6–8`, `:78` | Listen und Datum umstellen |
| relative Pfade: `alfa-theme.css`, `material/…`, `lieferung-an-code/fonts/geist.css` | `ALFA Shell.dc.html:12`, `:17`; `ALFA Dienste.dc.html:56` | nichts bei flachem Stamm |

**Größte Grenze:** `dc-import` nur im selben Ordner. Sie verbietet Ordner je Modul und erzwingt den flachen Stamm.

## 5 · Umzugsplan für (b) (nicht ausführen)
1. Johannes beantwortet die Fragen 1–6.
2. **Modul-Liste anlegen:** `DESIGN-STRUKTUR/module.json`, je Modul seine Bögen, Vorsilben, Einstellungen und Routen. Startwerte aus `verflechtung.json`. Nur lesen, nichts verschieben. Umkehrbar: Datei löschen.
3. **Editoren auf die Hülle vom 29.10. umstellen,** Bogen für Bogen, mit Bildvergleich. Gezeichnet wird in Claude Design.
4. **Werkzeuge** (`lauf.js`, `apply.js`, `pruefung.js`, `t9-css.js`) lesen Bogennamen und Bereiche aus der Modul-Liste. Erst messen (`write: false`), dann schreiben.
5. **Zweige:** `DESIGNCHANNEL` = Stand. Ein Zweig je Arbeit (z. B. `design/aufmass-ebenen`). Eine Lieferung bekommt ein Tag (z. B. `lieferung-2910`).
6. **Prüfung je Lieferung:** Die Hülle-Dateien existieren nur einmal; die Verflechtungskarte ist gegen die Bögen abgeglichen.

## 6 · Fragen an Johannes
1. Wo liegt der aktuelle Export von Etappe II mit `ALFA Projekte.dc.html` und dem Projektformular? Er fehlt mir.
2. Bleibt der Design-Stamm flach? Das ist die Bedingung für (b).
3. Soll der Hub im Design ein eigenes Fachmodul sein oder nur Teil von Einstellungen?
4. Sollen die Einstellungen im Code künftig Beiträge der Module einsammeln statt einer festen Liste?
5. Gilt N20 („nie ausgegraut“) für alle Bereiche?
6. Wer pflegt die Verflechtungskarte: die Design-Sitzung bei jeder Änderung, oder die Code-Sitzung?
