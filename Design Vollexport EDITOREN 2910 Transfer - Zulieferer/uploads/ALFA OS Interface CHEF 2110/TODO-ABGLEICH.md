Export: 19.10.2026

# To-do-Abgleich rückwirkend · 19.10.2026
Johannes 19.10.: „dann bitte dringend rückwirkend noch nciht erledigte To Do´s suchen udn abgleichen.“
Quellen gelesen: entscheidungen.md (ganz), RUECKGABE-AN-CODE.md, ABNAHME.md, AUDIT-BERICHT.md, UEBERGABE-NAECHSTER-CHAT.md, PROMPT-NAECHSTE-SESSION.md, akte.json. Stand je Zeile: **offen** (kein Beleg einer Umsetzung gefunden), **teils**, **gebaut, nicht bestätigt** (Johannes oder echte Maus noch nicht), **erledigt** (Beleg). Gesucht mit grep im Projekt; „kein Treffer“ heißt: nicht im Projekt, nicht, dass es nie gemacht wurde.

## A · Offen (kein Beleg einer Umsetzung)
| Nr | Wort von Johannes | Stand | Hinweis |
|---|---|---|---|
| A1 | 13.10.: „Zur "Lupe" hatte ich einen schönen "maßband dass ausfährt" animations entwurf, suche den bitte.“ | offen | grep Maßband/Lupe: 0 Treffer in allen Bögen und JS. Entwurf liegt nicht im Projekt. Johannes müsste ihn liefern oder die Quelle nennen |
| A2 | 13.10.: „Danach - aus den drei bildern im anhang EINES aussuchen, daraus ein ausgewogenes … Farb Vorschlag als Leiter.“ · „5 - es gibt noch keine.“ (Farbleiter) | offen | ALFA Farbsystem = Vorschlag, nicht entschieden (akte.json offen). design-system/alfa-ds*.js tragen noch „Stahl“ als ersetzt |
| A3 | 17.10.: „Die mitte kann auch wachsen, alles ist je ansicht "locked" oder nicht. ENTSCHEIDE ICH SPÄTER, bauen.“ (Rückgabe 16.10. Punkt 2: „Sperre je Ansicht als Schalter vorsehen“) | offen | Schalter nicht gebaut (grep lock|sperre in alfa-shell.js: 0 Treffer; in den Seiten nur die App-Sperre als Einstellung) |
| A4 | 18.10.: „Diagonale Toleranz: Maus darf schräg zum Eintrag laufen, bis sie ankommt (wie macOS)“ | offen, nicht baubar ohne Zielangabe | Das Blob-Menü ist eine senkrechte Liste ohne Untermenü (Johannes 13.10.: „auch hat niemand gesagt, dass das blobmenü einen untermenü popout bekomnmt“). Heute: Zeile wird nach 160 ms Verweilen heiß (ALFA Shell.dc.html:181 `aim`), Durchlaufen überspringt Zeilen. Ein „Dreieck zum Ziel“ braucht ein Untermenü; ohne eines ist die einzige Lesart eine Geschwindigkeitsprüfung, die ich nicht belegen kann. Und Bewegung ist nur mit echter Maus bestätigbar |
| A5 | 18.10.: „Fold/Unfold der Spalten … nach Nutzer Informations-Sichtbarkeiten und der "informationsdichte" des Inhaltes und performance tunen.“ | teils | Klick-Verhalten gebaut (18.10., nach 22:50). Dichte je Inhalt und Performance: keine Messung, kein Beleg |
| A6 | 18.10.: „Assistent können wir noch richtig ausarbeiten - bitte als Tod Do merken!“ | teils (19.10.) | Zustände Ruhe, Eingabe, Denkt, Verlauf, Fehler als Entwurf in ALFA Entscheidungen 7, nicht in ALFA Shell gebaut, nicht abgenommen. Vollansicht und Menüeintrag: „später“ (Johannes 16.10.), nicht gezeichnet |
| A7 | 16.10.: Assistent „Menüeintrag ja, aber später und als "navigations-Item"“ | offen | gehört zu A6 |
| A8 (erledigt 19.10.) | Rückgabe B28: „IN den EINSTELLUNGEN „mailkonten“ signaturen anlegen, in Mails client nur „wählen““ · 13.10.: „pro Postfach im Einstellungs Ansichtsbereich einen "Signatur" anlegen, auswählen erstellen“ | teils | Block `signatur` (Konto, Text, Schalter) ist jetzt in Gruppe „Ich“ erreichbar (CATSET.Ich: profil, signatur, darstellung). „Je Postfach“ anlegen und wählen ist nicht gebaut: es gibt eine Signatur für ein Konto (Dummy), die Mail-Konten-Karte hat keine Signaturzeile |
| A9 | 17.10.: „Die Schrift bzw die Einzüge, Kerning und auch Ausrichtung der "Namen" verbessern … ist eine "rechtsbündigkeit" der namen sinnvoll?“ · „…Namen eventuell auch im deutschen verständlich … durch geläufige synonyme oder anglizismen zu optimieren?“ (Kacheln) | offen | Antwort an Johannes nie dokumentiert. Kachelnamen heute: Dienstnamen (Clockodo, DHL …) und „Schlüssel-Inventar“ |
| A10 | 17.10.: „Kacheln … mit Icon der jeweiligen Anbindung“ | teils | Logos für 2 von 10 Diensten (clockodo.png, dhl.svg; dhlversand nutzt dhl). 8 fehlen, akte.json offen |
| A11 | 15.10.: Kommentare `shell-snap` („Wieso 10? …“), `shell-blob-assist-folded` („?“), `shell-blob-menu-folded` („?“) | erledigt durch Wegfall (19.10.) | Sie hingen an der alten Designsystem-Seite (design-system/, gelöscht 19.10.). grep nach snap, assist-folded, menu-folded in allen Dateien: 0 Treffer; kein Token, keine Konstante in alfa-shell.js oder TOKENBOGEN.json. `blob-eye 4 × 8` bleibt beantwortet |
| A12 | 17.10.: „kann ich garkeine Mails mehr "verfassen"?“ · „BLOB kann nicht mehr angeheftet werden?“ | unklar | Verfassen: `newDraft` und „Neue Mail“-Knöpfe laufen (Funktionstest 19.10. in ALFA Mail v2). „Blob anheften“: kein Treffer (angeheftet, blobPin) – Johannes fragen, was gemeint ist |
| A13 | 17.10.: „Evtl einen kleinen schönen … "tool tip" dazu?“ → „Komplett wie bei MacOS“ | erledigt | System-`title` (Rückgabe Punkt 30) |
| A14 | 14.10.: „cheche auch die BLOCKS, bibliotheken etc!!!“ · „check die icons!“ | teils | bauteile.json (75) deckt Bauteile; Icons: kein eigener Prüflauf, Belege fehlen |
| A15 | 13.10.: „Icon: Nimm Alle mit … App Icon B : A-Monogramm wird vorläufiges Dockbar MacOS und distribution App Icon.“ | teils | material/icons/app/* in akte.json „benutzt“; kein Beleg, dass App-Icon B als Dock-Icon geliefert ist |
| A16 | 11.10.: Karten 8a/8b: „beide Mitnehmen, details folgen“ · „4c - hellgrau mit Haarlinie sehen“ · „3 - … iOS, iPadOS, SaaS … als Systemfrage“ | teils | 8a/8b als Prop `stack`, hellgrau als `ground`. „details folgen“ und die Systemfrage iOS/iPadOS/Web sind nie beantwortet |
| A17 | 11.10.: „Widgets sind JETZT kein thema.“ · Bahnen horizontal zerschneiden für Paletten | später | nicht planen, nicht bauen |
| A18 | 13.10.: „1 - wie gehen wir dann mit wirklich produktiven Postfächern um? … 3201 Mails“ | teils | Liste: 60 Zeilen sichtbar, Platzhalter für den Rest, bei Scroll +120 (ALFA Mail v2 `lim`). Keine echte Virtualisierung, nicht gemessen (Break UI) |
| A19 | 17.10.: „Hell und Dunkel im 1:1 darstellungsdesign der modi und tokenbogen vorgaben anzeigen“ | erledigt | ALFA Designsystem (akte.json „Farbe hell/dunkel“) |
| A20 | 17.10.: „ALLE "zeigen" Entscheidungen … auf EINEM EINZIGEN BOGEN sammeln. Alles andere … Doppelte, überholte … löschen.“ | erledigt bis auf Johannes-Wahl Farbsystem | ALFA Entscheidungen ist der Bogen; überholte Proben 7 A/B entfernt (19.10., beide von Johannes entschieden). ALFA Huelle bleibt: Register Entwurf gegen Code, github.md Screen map, von Johannes 14.10. („am Render gegen den Stand von heute messen“) gewollt. ALFA Farbsystem bleibt, bis die Farbleiter entschieden ist (A2, wird in ALFA Entscheidungen 5 geladen) |
| A21 | 18.10.: „token für haarlinie anlegen bitte. Designsystem dringend nachziehen, es ist veraltet und wohl weitestgehend nichtmehr gültig, oder?“ | erledigt (19.10.) | Token `size.hairline` da. `ALFA Designsystem.dc.html` liest seit 18.10. TOKENBOGEN.json live. `design-system/` (alfa-ds-tokens.js, alfa-ds.css, „Stahl“ ersetzt) wurde von keiner Datei geladen (grep 0 Treffer) und ist gelöscht, gedeckt durch 17.10.: „Alles ALTE wird dringend und umfassend entfernt.“ |
| A22 | 18.10.: „Fremd KI Audit … du willst den audit auf garkeinen fall nicht bestehen!“ | offen | ABNAHME Zeilen 1, 2, 4, 6, 10, 11, 12 stehen auf ⏳ |

## B · Gebaut, aber nicht bestätigt (echte Maus oder Johannes)
- Kacheln einrasten per CSS scroll-snap (y mandatory, scroll-padding-top 8): nicht mit echter Maus bestätigt (entscheidungen.md 18.10., 22:24).
- Haarlinie unter dem Kopf nur beim Scrollen (Einblenden 320 ms, Ausblenden 900 ms nach 420 ms): nicht bewegt gemessen.
- Doppelklick auf gefaltete Bahn = Ruhemaß 280: zweite Messung des Prüfers nicht abgewartet (UEBERGABE Flags).
- Mehrfachauswahl in ALFA Mail: „nicht abgenommen“ (RUECKGABE A9, ALFA Entscheidungen 5).
- Blob überlagert Menü/Toast: Menü im Bild gemessen 19.10. (Blob oben); Toast überlappt in Ruhelage nicht; seitlich gedockt nicht gemessen.
- Orb im Blob, Toast 8 über dem Kartenfuß, Kontextmenü auf 56er-Raster: gebaut, ohne „so“ von Johannes.

## C · Gefunden beim Trennen (19.10., neu, nicht von Johannes)
Siehe TRENNUNG-BERICHT.md (v2 am 19.10. eingesetzt, Dateinamen ohne „v2“): Schlüssel `pkey` mit alten deutschen Propnamen (Eigenschaftsänderung setzte die Karten nicht zurück); `kLook`, `kLookGo`, `kAbschnitt` ohne Leser; Block-Zweige für Kontakte, Kürzel, Backups u. a. ohne Weg dorthin; `by` in `fromProps` mit alten Schlüsseln (Person/Ansicht/System), greift nie.

## D · Von Johannes offen (aus Prompt)
Fokus-Abstand 2 oder 1 · Kachelhöhe 112 oder 96 · 87 Tokens designSet auf ALFA Entscheidungen 6 · Sperre je Ansicht · Prop-Werte System/Geist/Ring, Zustandswörter, `kind: "setting"` deutsch lassen oder übersetzen · ALFA Huelle/Farbsystem · design-system/ löschen oder nachziehen.

## E · Frage 5/6 aus dem Prompt, beantwortet (19.10.)
- Textstile ↔ Apple: Zuordnung als Vorschlag im Token (`typography.textStyle.*`, Feld `apple`), Quelle Apple HIG macOS Typography (Tabelle) und WWDC20 10175. Body 13/16 gleich, Title 2 17/22 gegen ALFA 18, Subheadline 11/14 gegen ALFA 11,5, 9 pt ohne Entsprechung. Dynamic Type unter macOS: kein Beleg gefunden (offen).
- ALFA Huelle, ALFA Farbsystem, design-system/: siehe A20, A21.

## F · Gestrichen 19.10. (nicht von Johannes)
320 px, Zoom 200 %, RTL aus uploads/SKILL.md Phase 4. Kein Wort von Johannes dazu; 16.10.: Mindestfenster nachrangig, Fullscreen-App. Nicht Teil der Abnahme.

## G · Brief v9 (19.10., Code → Design)
Siehe BRIEF-V9-ABGLEICH.md: T1 bis T8 offen, T6 W-03 und W-04 erledigt, L-015 und L-016 brauchen einen Wert, L-008, L-009, L-012, L-013 nicht gezeichnet.

## G (Nachtrag 19.10.)
Brief v9: contract/ gebaut (P1 valid, P2 consistent). Offen: T5 (L-008, L-009, L-012, L-013 zeichnen), T6 W-05 bis W-07, T7 Skripte, motion.transition.*, Zustands-Tokens je Bauteil, `en`-Texte, diff_contract-Port.

## H · Stand abends 19.10.
Brief v9: T5 gebaut bis auf L-011 (Logos brauchen Material von Johannes), P1 bis P3 grün, W-07 erledigt. Offen: werte-abgleich.json per Skript, W-08 bis W-10, Zustands-Tokens je Bauteil, en-Texte, Bestätigung durch Original-Skripte bei Code.

## I · Korrektur 19.10. abends (Code-Dokumente gelesen)
Die Punkte Kachelhöhe, Kartenstapel, Firmendaten/Impressum, Fokusring, Mehrere Konten sind von Johannes beantwortet (Wortlaut in entscheidungen.md, Eintrag „Zu Offen …“). Offen bleibt: Sperre je Ansicht, Farbleiter, Fensterhöhe, Reife (set-by-design bauen?), Lupe, „Blob anheften“, Logos, Kachelnamen, Kind-DCs, „raus“. Neu: Namen unter der Oberfläche englisch (Prop-Werte, Zustandswörter).

## J · Konto-Wähler
Kein fertiges Bauteil bei Code und keines bei Design: ALFA Entscheidungen 8 zeigt A (Wähler im Kopf, Tendenz), B (Marken), C (Gruppen). Erledigt als Entwurf und Bau am 19.10. nach Johannes' Kommentar (Klick auf „Postfach“, schmal): ALFA Mail, ALFA Entscheidungen 8, Vertrag. Offen: Abnahme, Messung hell/dunkel Kontrast, Datensatz mit langen Adressen, Verhalten mit echter Maus.
