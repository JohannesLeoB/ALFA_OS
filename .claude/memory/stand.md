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
- Test: eine große Testdatei plus `HullProbeTests.swift` (zu überführen); `testLines` 5885/5895.

## Ungeprüft
- K1, H2, D1, HTML-Mail, H1, IDLE, kein doppeltes Senden, F32: nicht in der laufenden App oder gegen echte Server gesehen. Nichts ist grün; Abnahme nur durch Johannes. Letzte App: `dist/ALFA OS 943.app` (ohne F32).

## Offen bei Johannes
- Rote Mail-Funktionen und Formatleiste: Design zeigt Vorschläge, er entscheidet je Fall.
- Erklärsätze in der App streichen (Liste siehe spec-hub HUB-R02, spec-huelle HUELLE-R10).
- Mail-Hülle: Untergrenze der Bahn Links (HUELLE-L06).
- Ort der Kontakte; Erst-Setup; Sperre der App; Wächter-Frage.
- Draws: Testgrenze bleibt, Patch geparkt; Draws-Master kommt zuerst zu ihm.

## Nächste Schritte
1. Design-Prompt (Mail, Hub, Hülle) nach seiner Freigabe an Design.
2. Erklärsätze streichen.
3. Aufräumen: `HullProbeTests` überführen; Fundus (`myk`-Reste, deutsche Namen); SheetValues-Quellen; Datenspeicher (wartet auf Johannes).

## Bekannte Fehler
- Mail: doppeltes Senden möglich, wenn die Sendeprüfung scheitert (`Mail/Core/MailCore.swift:387-395`); wartende Mail geht bei Konto-Entfernen verloren, die Karte zeigt „gesendet“ (ungeprüft); `loadMore` ohne Aufrufer; `actionFailures`/`saveFailure` von der App nie gelesen; Befehle `leadFromMail`, `attachmentToProjectFolder` ohne Leser; Kontakte schreiben bei jeder Änderung nach UserDefaults.
- Hub: Trennen bricht halb ab, wenn das Schlüsselbund-Löschen wirft (`Hub/HubCore.swift:493-519`); Schlüssel-Erneuerung ohne Rückfall; `ServiceSetting` ohne Deklarierer; ClickUp ohne Fähigkeit; Claude-Schlüssel im Hub und Fundus unter verschiedenen Namen; Drive 403 gilt als Anmeldefehler; Hub-Fehlerpfade ohne Test.
- Fundus: 118 Zeilen mit `myk` in 47 Dateien, deutsche Namen, toter Mail-Zweig.
- Commits `eb89ff4`, `b1c753e` ohne Leerzeile nach dem Betreff (Force-Push verboten).
- Abweichungen vom Master, bewusst: Kachelhöhe 112, Suche über alle Ordner, HTML-Mail zeigt echten Inhalt, Toast „Entwurf gesichert“ nur bei Erfolg.

## Ablage
- Draws: Clone `~/Developer/ALFA_DRAWS`, Zweig `alfa-draws`, Konto `bergerjohannesleo-dot`; arbeitet nur dort.
- Fremde Ordner in `dist/`: `anatomy-map`, `farbe`, `hotline-quotes`, `review`, `kit-drawing`, Worktree `wt-drawing` (Zweig `drawing`, nur lokal); löschen nur auf Johannes' Wort. `dist/lead` gehört dem Pate.
- Zitat-Triage-Sitzung wartet auf Johannes (`dist/lead/inventur/ZITATE-TRIAGE.md`).
