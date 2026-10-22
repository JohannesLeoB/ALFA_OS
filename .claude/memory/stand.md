---
name: stand
description: Laufender Stand ALFA_OS (22.10.): Regeln, Gebautes, Ungeprüftes, Offenes, nächste Schritte, bekannte Fehler; Lücken und Funktionen stehen nur in den Specs
metadata:
  type: project
---

Nur, was heute gilt. Verlauf: `git log`. Funktionen, Lücken, Entscheidungen von Johannes: `spec-*.md` (Format: `spec-format.md`).

## Repo und Regeln
- `main` = GitHub. Regeln `AGENTS.md` §1–§13, Karte `README.md`, Gedächtnis per Link (§12). Commit-Nachricht vor dem Commit mit `git log -1 --format=%B | cat -vet` prüfen.
- 13 Stränge in `.claude/agents/`; gebaut wird über die Bau-Stränge (Sonnet 5.5), die Lead (Opus) prüft, liest den Diff und besitzt die Tests (ARBEIT-R24 gilt bis ARBEIT-O02).
- GitHub: `main-protect` (kein Force-Push, kein Löschen, lineare Historie), `only-main` erlaubt `main` und `alfa-draws`.
- Master: `ALFA OS Interface CHEF 1610-handoff 1810.zip` (Rang latest), vorletzter `…CHEF 1610.zip`; gezeichnet nur Mail, Einstellungen, Hülle. Brief v12 (b71bea8) gilt, 24 Punkte. Neuer Export von Design steht aus.
- Figma-Spiegel: Probedatei „ALFA Verlauf · Mail“ (Team ALFA, Starter); Strang und Automatik nicht freigegeben.

## Gebaut (Details in den Specs)
- Hülle, Einstellungen, Mail (Liste, Lesen, Verfassen, Postausgang, Kontakte, HTML), Hub (Anbieter-Prüfung, Abgleich beim Start, Einstellungen je Dienst, Drive-Port aus), Pipeline (Generator, `receive_master.py`, `build_app.sh`).
- Nicht gebaut: Projekte, Heute, Kataloge, Warenkorb, Datan.
- Testplatz: `testLines` 5869 von 5895; der wiederholte Aufbau lässt sich nur um 30–50 Zeilen kürzen (gemessen); Stück 5 braucht rund 40: Anheben der Grenze liegt bei Johannes.
- Test: genau eine Testdatei, `WholeAppTests.swift` (HullProbeTests am 22.10. nach Johannes' Wort gestrichen, Ziel-Test ALFA_OSTests aus `project.yml` entfernt); `testLines` siehe Hook-Ausgabe.

## Ungeprüft
- Abmelden mit Halten, Hover-Leiste öffnet die Mail nicht mehr, Fokusring am Griff nur bei Tastatur (gebaut ohne Test, Randfälle in HandleView offen), K1, H2, D1, HTML-Mail, H1, IDLE, kein doppeltes Senden, F32: nicht in der laufenden App oder gegen echte Server gesehen. Nichts ist grün; Abnahme nur durch Johannes. Letzte App: `dist/ALFA OS 943.app` (ohne F32).

## Offen bei Johannes
- Rote Mail-Funktionen und Formatleiste: Design zeigt Vorschläge, er entscheidet je Fall.
- Grenzfälle der gestrichenen Erklärsätze (HUB-R02): zurückholen oder weglassen.
- Mail-Hülle: Untergrenze der Bahn Links (HUELLE-L06).
- Erst-Setup; Sperre der App; Wächter-Frage. (Kontakte: J 22.10., Hub-Quellen inklusive eigener lokaler Datenbank, siehe HUB-F41; kein UserDefaults.)
- Draws: Testgrenze bleibt, Patch geparkt; Draws-Master kommt zuerst zu ihm.

## Nächste Schritte
1. Design-Prompt (Mail, Hub, Hülle) nach seiner Freigabe an Design.
2. (erledigt 22.10.) Erklärsätze gestrichen; Grenzfälle siehe spec-hub HUB-R02; App noch nicht neu gebaut.
3. Aufräumen: Fundus (`myk`-Reste, deutsche Namen); SheetValues-Quellen; Datenspeicher (wartet auf Johannes).

## Bekannte Fehler
- Mail: Doppelsenden bei gescheiterter Sendeprüfung ist seit 22.10. geschlossen (MAIL-R03), offen (Prüferfund, praktisch nicht erreichbar): `MailModel+Draft.swift:205-210` fällt auf send zurück, wenn `resend` nil liefert, auch bei vorhandener `outboxID`; Schutz und Prüfung sobald Testplatz da ist; wartende Mail geht bei Konto-Entfernen verloren, die Karte zeigt „gesendet“ (ungeprüft); `loadMore` ohne Aufrufer; `actionFailures`/`saveFailure` von der App nie gelesen; Befehle `leadFromMail`, `attachmentToProjectFolder` ohne Leser; Kontakte schreiben bei jeder Änderung nach UserDefaults.
- Hub: Trennen ist seit 22.10. ganz oder gar nicht (Schlüsselbund-Fehler rollt zurück), offen: Datenbankfehler nach dem Löschen der Schlüssel; Schlüssel-Erneuerung ohne Rückfall; `ServiceSetting` ohne Deklarierer; ClickUp ohne Fähigkeit; Claude-Schlüssel im Hub und Fundus unter verschiedenen Namen; Drive 403 gilt als Anmeldefehler; Hub-Fehlerpfade ohne Test.
- Fundus: 118 Zeilen mit `myk` in 47 Dateien, deutsche Namen, toter Mail-Zweig.
- Commits `eb89ff4`, `b1c753e` ohne Leerzeile nach dem Betreff (Force-Push verboten).
- Offen (klein): `pointerFocus` in `HandleView.swift` auch in `onKeyPress` zurücksetzen, damit der Ring nach Ziehen und Pfeiltasten erscheint; Abmelden-Pille zeigt dieselbe Frage wie das Zeilenlabel (Master zeichnet keine eigene Frage, Lücke bei Design, N2).
- Commit `a5d8e43` trägt einen Spec-Betreff, enthält aber auch die drei App-Dateien (Abmelden mit Halten, Hover-Leiste, Fokusring); vor jedem Commit `git diff --cached --stat` prüfen.
- Abweichungen vom Master, bewusst: Kachelhöhe 112, Suche über alle Ordner, HTML-Mail zeigt echten Inhalt. Toast „Entwurf gesichert“ steht wie im Master nur bei Inhalt; das Scheitern des Sicherns ist nicht gezeichnet (Lücke MAIL-L13).

## Ablage
- Draws (leitend und bauend, Johannes 22.10.): Sitzung „11_ALFA_OS DRAWS 02 BAU“, Clone `~/Developer/ALFA_DRAWS`, Zweig `alfa-draws`, Konto `bergerjohannesleo-dot`; Nachrichten dorthin, Texte vorher Johannes zeigen. Sitzung „10_ALFA_OS DRAWS 01“ ist inaktiv; ihre Reste (Worktree, Zweig `drawing`, `drawing`-Ordner in `dist/`) sind am 22.10. nach Johannes' Wort und Draws' Antwort gelöscht.
- Fremde Ordner in `dist/`: `anatomy-kitchen`, `anatomy-map`, `farbe`, `hotline-quotes`, `review`; löschen nur auf Johannes' Wort. `dist/lead` gehört dem Pate.
- Zitat-Triage-Sitzung wartet auf Johannes (`dist/lead/inventur/ZITATE-TRIAGE.md`).
