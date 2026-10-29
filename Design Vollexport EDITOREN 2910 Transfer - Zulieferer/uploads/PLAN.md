# PLAN · Aufräumen und Polieren · Start 15.10.2026

Stand zeigt Johannes. Nichts wird gelöscht, bevor er die Liste mit „so“ bestätigt hat. Kein ZIP.

## Durchgänge
- [x] 0 · Bestandsaufnahme der 12 Seiten und der Ordner (gelesen, nichts geändert)
- [x] 1 · Abgleich Einstellungen (Tabelle in `EINSTELLUNGEN-ABGLEICH.md`) → Johannes bestätigt
- [x] 1d · 16.10.: Tokenbogen 216 Tokens (lane hell/dunkel, tote Verweise behoben, component mit Typ). `alfa-ds-tokens.js` liest TOKENBOGEN.json (0 Abweichungen). Mehrfachauswahl in Mail und Designsystem 04b. Geist Mono aus Tokenbogen und Dienste entfernt. Alle Hexwerte in Mail stehen im Tokenbogen oder in alfa-theme.css.
- [ ] 2 · Mix bauen: Hub und Tiefe aus `Einstellungen Inhalt`, Stapel und Übersicht aus Mail, ein Bereich
- [ ] 3 · „Johannes entscheidet“-Bogen (Bestätigen, Bestätigen Bogen, Dienste, offene Fragen)
- [x] 4 (16.10.) · Hülle ohne Umlaut als `ALFA Huelle.dc.html`. Nicht entfernt: Ihr Register Entwurf gegen Code enthält Zeilen, die nirgends sonst stehen (Leiste 60 gegen 52, Falten unter 112 gegen 120, größte Seitenbahn 380, Akkordeon, Griff). Nachgezogen: Ruhe 280/280, Mitte 280, Fenster 960 × 600, Mono entfernt. Lädt, Rechnung 1456 − 280 − 280 = 896.
- [ ] 4 alt · Hülle ohne Umlaut umbenennen, mit Shell abgleichen, nur bei Verlustfreiheit entfernen
- [ ] 5 · Tokenbogen: jeder Wert mit Datei und Zeile, ein Stand (`TOKENBOGEN.json`), `design-system/` auflösen
- [ ] 6 · Designsystem-Seite auf den Tokenbogen umstellen, Farbleiter und Shell Bogen erst danach entfernen
- [ ] 7 · Polieren Mail und Einstellungen: Durchgänge A Raster, B Werte gegen Tokens, C Bewegung, D Farbe und Kontrast, E Zustände und Texte, F Abgleich mit der Shell
- [x] 8 · Ordner aufgeräumt (16.10., Johannes: „so“). Gelöscht: Austausch, altmaterial, archiv, paket-01, design_handoff_alfa_mail_einstellungen, screenshots, auftraege, sicherung, Farbleiter.dc.html, alte MDs und WERTE.json, design-system/ bis auf alfa-ds-tokens.js und alfa-ds.css. Geblieben: uebergabe-code/ und INHALT.json (Code), uploads/ (nie anfassen), material/icons.

## Vorgabe von Johannes (15.10.)
Mail ist eine Seite. Einstellungen ist eine Seite. Keine Navigation zwischen ihnen, kein „Inhalt“, kein Bereichs-Schalter.

## Kontrolle je Durchgang
Messen am Render bei 1512 × 982, hell und dunkel. Fundstelle (Datei, Zeile) und Wert. Verifier-Lauf. Liste „nicht geprüft“.

## Offene Fragen an Johannes
- Hub aus Kacheln als Startansicht der Einstellungen?
- Lastenhefte und Specs der App-Codes: wo liegen sie?
- Mehrere Mail-Konten: Wähler oder gestapelt?

## Rückgängig
- 15.10. Löschung von `ALFA Einstellungen.dc.html` zurückgenommen (Johannes: „das war vorher viel besser“). Wiederhergestellt aus `uebergabe-code/`. `ALFA Einstellungen Inhalt` leitet beim Einzelaufruf dorthin weiter. Meine Annahme „Dummy-Navigation in Mail“ war falsch begründet.

## Stand 16.10. abends, offen für den Arbeits-Chat
- ALFA Einstellungen: Hülle plus Kacheln aus Inhalt; die Logik (Zeilen 37 bis 736, renderVals ab 442) trägt noch Mail-Daten, Entwürfe, Kontakte, Stapel. Für die Hülle gebraucht: area, licht, wArr, lanes, groups, badges, sync, menu, toast, mem, geo, lay. Neu schreiben und nach jedem Schnitt am Render prüfen.
- Stapel mit Übersicht aus Mail in die Einstellungen ziehen (Mischung, Johannes 16.10.).
- Designsystem liest weiter alfa-ds-tokens.js (Namen, Belege, Bilder) mit Werten aus TOKENBOGEN.json. Farbleiter und Federn sind nur dort.
- Bögen Shell Bogen, Farbleiter, Hülle, Bestätigen, Dienste: nicht abgeglichen. Bogen Johannes entscheidet ersetzt Bestätigen, Bestätigen Bogen, Dienste erst nach „so“.
- Ordner aufräumen: Lösch-Liste zeigen, nichts gelöscht.
- Nicht am Render geprüft: Mehrfachauswahl, Dunkel in Einstellungen, ALFA Dienste nach Mono-Entfernung.
- lieferung-an-code/: decisions.json, settings-sections.json. Codes Block B und C brauchen Antworten von Johannes.

## Nach dem Aufräumen: nicht neu geladen
Keine Seite wurde nach dem Löschen geladen. Einzeln prüfen: Mail, Einstellungen, Shell, Designsystem, Tokenbogen, Dienste.
