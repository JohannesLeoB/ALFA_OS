Export: 19.10.2026

# Trennung Mail / Einstellungen · Bericht 19.10.2026
Auftrag: PROMPT-NAECHSTE-SESSION Aufgabe 1; Johannes 17.10.: „MAIL ANSICHT als Page, EINSTELLUNGEN als Page“; 19.10.: „erst trennung“. Johannes 19.10.: „go!“ → v2 an die Stelle der alten Bögen gesetzt (gleiche Dateinamen); die Dateien `… v2` gibt es nicht mehr.

## Dateien
- `ALFA Mail.dc.html` (neu, Seite Mail, feste Fläche Mail, kein Prop `area`/`settingsGroup`)
- `ALFA Einstellungen.dc.html` (neu, Seite Einstellungen, eigene Logik, lädt nicht mehr ALFA Mail)
- `alfa-bausteine.js` (global `window.AlfaBausteine`, wie alfa-shell.js): einmal für beide
  - Daten: Symbolpfade `P`, Kartenebenen `LEVELS`, `GROUPS`, Dienste `SVC` mit Zustand, `ME`
  - Zustandswörter `csOf`, Zeilen/Hinweis/Textknopf (`row`, `toggleRow`, `notice`, `tb`)
  - Menü (`menuW`, `menuX`, `openMenu`, `mi`), Toast (`toastIt`), Kante (`edgePulse`, `edgeTr`, `onLScroll`)
  - Falten/Ruhemaß (`mem`, `setMem`, `lay`, `grow`, `A`, `D0`), Übersicht (`ovAnim`), Namen (`ini`, `mid`, `gr`, `nf`), Synchronisieren (`sync`)
  - `mixInto(prototype)`; die Seite setzt `AREA`, `CARDS`, `FANNED`.
- Nicht einmal, sondern je Seite: das Markup (DC-Vorlagen können keine Bausteine teilen ohne Kind-DC; Kind-DC bewusst vermieden, siehe Abschnitt „Bleibt doppelt“).

## Messung gegen heute (1512 × 982, Übergänge aus)
Vergleich Element für Element (Teil, Text, x, y, Breite, Höhe, Farbe, Fläche, Schrift, Radius, Schatten, Deckkraft, z): alt gegen neu.
- Ausgangszustand hell und dunkel: Mail 561 Elemente, Einstellungen 333 Elemente, **0 Abweichungen** (je Seite).
- Zustände dunkel, gleiche Eingriffe auf alt und neu, **0 Abweichungen**: Mail Übersicht (Stapel, Postfach), Entwurf vorn, Menü, Toast, Laden, Fehler, Leer, gefaltet, Suche; Einstellungen Übersicht, Dienst vorn (Claude), Gruppen Ich, Firma, Schutz und System, Menü, Toast, gefaltet.
- Funktionstest neu (ohne Fehler): Mail Ordner wechseln, Mail öffnen, Antworten, Dienste-Hinweis; Einstellungen Eintrag öffnen, verbinden, Gruppe wechseln, Abgleich, Schalter, Karte schließen.
- Mail-Zähler für die Hülle in Einstellungen (`mailUnread`: Demo 3, Eine 1, Schlimmster Fall 2, 1.284 899) gegen die Mail-Daten gezählt: gleich.
- **Nicht gemessen:** hell außer Ausgangszustand, Datensatz Schlimmster Fall / Eine / 1.284 in den neuen Seiten, Kontrast neu, Maus-Bewegung. Beide neuen Seiten tragen `Export 19.10.2026`.

## Verhalten geändert oder gestrichen (nicht von Johannes bestellt, bitte prüfen)
1. `pkey` nutzte die alten deutschen Propnamen (`entwurf`, `vorne`, `dienste`, `einstellung`, `daten`, `empfaenger`): Eigenschaftsänderungen setzten die Karten nicht zurück. v2 nutzt `draft`, `front`, `services`, `settingsGroup`, `dataset`, `recipients` (Fehlerbehebung, Wirkung nur im Prop-Wechsel).
2. `componentDidMount` las `props.licht` (alt); v2 `appearance`.
3. `kLook`, `kLookGo`, `kAbschnitt`, `laneSet`: keine Leser in den Projektdateien (grep 19.10.); in Mail v2 entfernt, in Einstellungen v2 `kLook*`/`kAbschnitt` behalten.
4. Einstellungen v2 hat keine Blöcke `kontakte` (nur über Mail erreichbar, dort ein Toast), keine Mail-Daten, keine Suche, keine Mail-Karten. Mail v2: `editContact`, `removeContact`, `addContact`, `openSet`, `closeSet`, Dienstblöcke entfernt; „Kontakt bearbeiten …“ und „Signatur bearbeiten …“ zeigen den Toast „Das steht in den Einstellungen“ (wie heute mit `area=Mail`).
5. In `fromProps` der Einstellungen bleiben die Schlüssel `Integrationen/Person/Ansicht/System` (greifen nie, immer `Integrationen`); unverändert übernommen, Fund.
6. Blöcke in Einstellungen ohne Zugang (`signatur`, `mitteilungen`, `kuerzel`, `backups`, `tagebuch`, `werkstatt`, `start`/`sperre` nur über Darstellung): unverändert übernommen. `signatur` ist Auftrag von Johannes (B28), siehe TODO-ABGLEICH A8.

## Bleibt doppelt (bewusst)
Vorlagen der Zeilen, Kartenköpfe, Kartenfüße, Menü, Toast stehen in beiden Seiten als Markup. Grund: Ein Kind-DC je Baustein ändert die Anordnung beim Streamen und wurde nicht gemessen. Wenn Johannes das als Verstoß gegen „Hülle nur einmal“ wertet: Kind-DCs `ALFA Zeile`, `ALFA Kartenkopf`, `ALFA Kartenfuß` als nächster Schritt, wieder mit Messung.

## Ersatz (19.10., nach „go!“)
`ALFA Mail.dc.html` = Mail-Seite, `ALFA Einstellungen.dc.html` = Einstellungsseite, beide mit eigener Logik. ALFA Huelle und ALFA Designsystem laden `ALFA Mail` ohne `area` (Mail): unverändert lauffähig. Gemessen nach dem Ersatz: Mail (Schlimmster Fall) und Einstellungen (hell, dunkel, Schlimmster Fall) laden, Bahnen 280 / 896 / 280, `AREA` Mail bzw. Einstellungen, keine Konsolenfehler. Zusätzlich gleichzeitig behoben (Break UI, siehe BREAK-UI-BERICHT.md) in Mail: URL-Umbruch, `title` für Betreff und Kartenkopf, Anhangnamen in der Mitte gekürzt – das ändert Maße gegenüber dem Stand vor der Trennung nur in diesen Fällen.

## Folgen
- `ABNAHME.md` Zeile 5: Messung hell und dunkel im Ausgangszustand ✅, Zustände nur dunkel; bis zur Messung der Lücken oben nicht „fertig“.
- Kind-DCs für Zeile/Kartenkopf/Kartenfuß: nicht gebaut (Risiko für Maße, nicht gemessen). Entscheidung offen, ob nötig.

## Nachtrag 19.10. (L-016)
Kontextmenü-Zeilen jetzt Radius 12 / Innenabstand 12 (vorher 8 / 8). `menuW` in `alfa-bausteine.js`: Innenabstand 12 und feste Lücke 8 vor der Zusatzspalte (vorher fehlte sie, Zeile „Mail in Projektordner sichern“ war bei 224 um 6 px zu schmal; jetzt 280). Ändert die Kontextmenü-Maße gegenüber dem Stand der Trennung.
