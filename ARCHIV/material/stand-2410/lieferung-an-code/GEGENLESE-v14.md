# Gegenlese Brief v13 ↔ Entwurf v14 ↔ Master 1810 ↔ Bögen heute · 23.10.2026
Arbeitsstand Design, nicht freigegeben. Nachtrag 23.10. 15:02 Z: v14 ist auf GitHub veröffentlicht (DESIGN/brief/BRIEF.txt 48ace40103f2), Zeilen gleich dem Entwurf dist/brief-v14; diese Gegenlese gilt für die veröffentlichte Fassung. Quellen: DESIGN/brief/BRIEF.txt (v13, GitHub), dist/brief-v14/BRIEF.txt und OFFENE-PUNKTE.txt (Entwurf, nicht im Repo; Kopie material/master-1810/), Master 1810 (dist/master-latest, Kopie material/master-1810/), contract/LIEFERUNG.json, entscheidungen.md.

## 1 Zeilenangaben v14 gegen Master 1810
103 Verweise geprüft (material/master-1810/refs.txt). Alle Mail:, Shell:, Dienste:-Verweise treffen die genannte Stelle im Master 1810. Verweise auf INHALT.json, TOKENBOGEN.json, RUECKGABE-AN-CODE.md nicht geprüft.

## 2 Lieferschein gegen v14 (Matrix von Code: ein Eintrag je Punkt)
- Entfallen in v14, im Schein noch vorhanden: N11 (→ N21), N14 (→ N30), N25 (→ N7), N34 (→ N28). Für einen v14-Schein streichen und ihre Fundstellen bei N21, N30, N7, N28 eintragen.
- Neu in v14, im Schein fehlend: N41 (gezeichnet, ALFA Einstellungen.dc.html:327, Pille ALFA Bestaetigen „Abmelden?“/„Abmelden“), N43 (releaseSpan, pointerStep: im Bogen nicht vorhanden; Antwort: Rechenschutz des Codes, kein Token, sofern Johannes nichts anderes sagt).
- Alle where-Zeilen stammen vom 22.10. 22:20; die Bögen haben sich seither geändert. Vor der Lieferung neu erzeugen, sonst meldet P4 die Zeilen und Prüfsummen.

## 3 v14 Teil 2 (Johannes) gegen Design-Stand
- 22.10. Bahngrenzen, Mail Links nicht über 280: war nicht gezeichnet. Jetzt alfa-shell.js AREA.Mail.max, grow() (Schein N36 done). Grenze gehört dem Bereich Mail, nicht der Hülle (Johannes 23.10.). Untergrenze offen (Teil 4).
- 22.10. Bilder in Mails laden, zwei Schalter: Hauptschalter in Datenschutz (ALFA Einstellungen.dc.html:329); neu je Postfach ein Schalter: IMAP-Postfächer (:269), Google-Postfach (:309). Schein N21 done.
- 12.10. Postfächer nur in Einstellungen und Hub verbinden: Der Postfach-Stapel in ALFA Mail wählt nur; „Postfach verbinden“ führt in die Einstellungen. Kein Widerspruch.
- 10.10. Keine Farbwelten, kein ALFAcolor: Widerspricht Johannes' Farb-Arbeit vom 22.10. hier (ALFA Mail Color, ALFA Farbsystematik, entscheidungen.md ab :376). Beide Bögen sind gesperrt und gehen nicht an Code. Frage an Johannes, ob 10.10. weiter gilt.
- 22.10. Rückfrage ist Einstellung, nie mehrfach: Postausgang fragt nur nach gescheiterter Prüfung, einmal („Ungeprüft senden?“, Johannes 23.10. „JO!“). Kein Widerspruch.

## 4 v14 Teil 4 (offen bei Johannes) – hier schon beantwortet
- Postfach-Wähler: Johannes hat ihn hier geführt (entscheidungen.md:391, :406–:420; Postfach-Stapel, Beschriftung, Wechsel). Schein N22 done.
- Zustand einer Mail nach gescheiterter Sendeprüfung: Johannes 23.10. (entscheidungen.md:436–:438). Gezeichnet im Ordner Postausgang.
- Übrige Punkte (Erst-Setup, 15 Integrationen, Abmelden-Warnung, Grenzfälle der Erklärsätze, Menüeinträge ohne Verhalten, Untergrenze Links, ClickUp, Firmenschlüssel, Katalog-Satz, Blob-Name): hier kein Wort von Johannes; nichts gezeichnet.

## 5 v14 Teil 5 (Code gebaut, abweichend) gegen Design
- Endgültig löschen nur, wenn der Server es kann: jetzt auch im Bogen (ALFA Mail.dc.html:743, Probe serverPurge).
- Drucken ohne Toast: jetzt auch im Bogen (Toast „Druckdialog“ an fünf Stellen entfernt).
- Abmelden trennt alle und startet neu: Bogen gleich (Toast nach Bestätigen).
- Postfächer als Zeilen über den Ordnern (MailAccountPicker): weicht ab; Design zeichnet den Postfach-Stapel unten in der linken Bahn. Code baut nach dem Bogen, sobald Johannes freigibt.
- Kontakte eigener Abschnitt, „Als Kontakt sichern“ im Befehlskopf, HTML-Mail auf hellem Blatt: im Bogen unverändert; offen für Design (N33, N16).

## 6 Brüche zwischen v13 und v14
- N40: v13 ließ Shell:40/:53 bis zu Johannes' Wort stehen; v14 nimmt sie auf „nach Auftrag der Lead“ (OFFENE-PUNKTE B3: kein Wort von Johannes). Bogen unverändert, Frage an Johannes.
- N40 Mail:758: v13 Entfernen-Liste und N2 widersprachen sich. Gelöst: der feste Text ist weg, die Zählung aus N2 steht (ALFA Einstellungen.dc.html:295, :327), die Folgenangabe nicht.
- N29 Datum (21.10. oder 06.10.): hier nicht belegt.

## 7 Funde in den Bögen beim Gegenlesen (nicht geändert)
- Untertitel der Kacheln in Einstellungen sind Erklärsätze nach der Regel vom 21.10.: „Name, Rolle, Kürzel im Team“, „Unter jeder Mail, je Konto“, „Gesichert und vorgeschlagen“, „Was die App lädt und teilt“ (ALFA Einstellungen.dc.html:233 und folgende). Nicht in N40. Frage an Johannes.
