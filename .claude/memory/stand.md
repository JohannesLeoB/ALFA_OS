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
- Master: `ALFA OS Interface CHEF 1610-handoff 1810.zip` (Rang latest), vorletzter `…CHEF 1610.zip`; gezeichnet nur Mail, Einstellungen, Hülle. Brief v14 gilt (N1 bis N43, Teil 2 führt die Entscheidungen). Neuer Export von Design steht aus.
- Figma-Spiegel: Probedatei „ALFA Verlauf · Mail“ (Team ALFA, Starter); Strang und Automatik nicht freigegeben.

## Gebaut (Details in den Specs)
- Hülle, Einstellungen, Mail (Liste, Lesen, Verfassen, Postausgang, Kontakte, HTML), Hub (Anbieter-Prüfung, Abgleich beim Start, Einstellungen je Dienst, Drive-Port aus), Pipeline (Generator, `receive_master.py`, `build_app.sh`).
- Nicht gebaut: Projekte, Heute, Kataloge, Warenkorb, Datan.
- Testplatz: `testLines` 5869 von 5895; der wiederholte Aufbau lässt sich nur um 30–50 Zeilen kürzen (gemessen); Stück 5 braucht rund 40: Anheben der Grenze liegt bei Johannes.
- Test: genau eine Testdatei, `WholeAppTests.swift` (HullProbeTests am 22.10. nach Johannes' Wort gestrichen, Ziel-Test ALFA_OSTests aus `project.yml` entfernt); `testLines` siehe Hook-Ausgabe.

## Ungeprüft
- Abmelden mit Halten, Hover-Leiste öffnet die Mail nicht mehr, Fokusring am Griff nur bei Tastatur (gebaut ohne Test, Randfälle in HandleView offen), K1, H2, D1, HTML-Mail, H1, IDLE, kein doppeltes Senden, F32: nicht in der laufenden App oder gegen echte Server gesehen. Nichts ist grün; Abnahme nur durch Johannes. Letzte App: `dist/ALFA OS 943.app` (ohne F32).

## Offen bei Johannes
- Master 2210 (in Arbeit): Pfad der ZIP, dann Prüfung und Wechsel.
- Rote Mail-Funktionen und Formatleiste: Design zeigt Vorschläge, er entscheidet je Fall.
- Grenzfälle der gestrichenen Erklärsätze (HUB-R02): zurückholen oder weglassen.
- Mail-Hülle: Untergrenze der Bahn Links (HUELLE-L06).
- Erst-Setup; Sperre der App; Wächter-Frage. (Kontakte: J 22.10., Hub-Quellen inklusive eigener lokaler Datenbank, siehe HUB-F41; kein UserDefaults.)
- Draws: Testgrenze bleibt, Patch geparkt; Draws-Master kommt zuerst zu ihm.

## Übergabe 23.10. (Lead-Bau gibt den Stab ab)
- Offen bei Johannes: (1) Testgrenze bleibt 5895 (steht 5869), kein Anheben; (2) neue Datei `alfaos/Kit/Sources/ShellCore/SheetSources.json` für Fundstellen der 123 SheetValues-Werte, ja oder nein (Kommentare im Code sind verboten); (3) Brief N40 ändern: `ALFA Mail.dc.html:758` aus der Entfernen-Liste nehmen (widerspricht N2) und `ALFA Shell.dc.html:40`, `:53` aufnehmen; Brief N41 (Abmelden-Pille) und N42 (gescheitert nach Prüffehler) aufsetzen und zeigen; (4) zwei Zeilen in AGENTS.md (§10 HullProbe, §12 „wörtlich“); (5) Google-Client-ID; (6) Pfad des Vormasters 2210 für die Design-Test-Sitzung.
- Design-Test-Sitzung: Brief liegt als Entwurf beim Pate (von Haiku gegengelesen), nur lesend, Stufe 1 nur Master 1810 gegen Vormaster 2210; Regeln nach Johannes' gesundem Menschenverstand (Mehrheit gilt, Eichwerte aus 1810, Merkwürdiges ansehen); Johannes sieht ihn vor dem Senden.
- Gemessen 23.10.: Generator und Master 1810 stimmen (`design_generate.py --check`); `SheetValues.swift` 123 Werte ohne Fundstelle, drei im Master nicht gefunden (`releaseSpan`, `pointerStep`, `orbSpot`); ca. 15 Zeitwerte fest im Kit (`CadenceChoice`, `HubConfiguration`, `MailSetup`, `ChangeWatchers`) gegen HUB-R03; in den Ansichten kein Designwert als Literal (nur Geometrie wie `/ 2`).
- Gesamtmission gemessen: Kit nutzt 78 von 1144 öffentlichen Fundus-Typen (8,9 k von 53,4 k Zeilen); größter Hebel: diese 78 Typen in ein eigenes kleines Paket, Tests schrumpfen (Mutationslauf unten), leere Hub-Ports erst mit Abnehmer.
- Johannes will kürzere, einfache Antworten ohne Technikdeutsch, keine Umgehungen, Perfektion statt Bloat.

## Funde des Pate 23.10. (vom Pate am Code belegt, von mir nicht einzeln nachgeprüft; nach Schwere, im Takt nach §6)
1. Endgültig löschen behauptet Falsches: ohne UIDPLUS wird nur `\Deleted` gesetzt (`fundus/…/IMAPSMTPMailTransport.swift:178-179`), `canPurge` ist fest true (`Hub/Providers/MailBinding.swift:11`), der Mirror entfernt die Mail (`MailCore.swift:216`), der Toast meldet „gelöscht“; soll: nur anbieten, wenn der Server es kann.
2. `canPurge` wird bei jedem Zeichnen jeder Papierkorb-Zeile gerufen (`MailRowView.swift:189` → `MailCore.swift:207-208` → `HubCore.resolve`, baut jedes Mal einen Transport; fehlt der Zugang, setzt es mitten im Zeichnen `.keychainUnreadable`).
3. Ohne Funktion: Entwurfsmenü „Drucken“ (`MailStackLane.swift:69`), `commands` ohne Leser (`leadFromMail`, „In anderen Projektordner“); nach MAIL-R10 Verhalten oder Johannes fragen.
4. Kontakte: leerer Kontakt wird sofort gespeichert, `editContact` erlaubt doppelte Adressen, jede Taste schreibt die ganze Liste (`MailContacts.swift:36,51-66`, `MailModel.swift:52`); gehört zu Stück 5.
5. PDF: `mailDocument` lädt den Text neu (`MailModel+Files.swift:47`), `MailPDF.render` läuft auf dem Hauptakteur; Seitenlayout fehlt im Master (Lücke §7, nie gemeldet).
6. Weiterleiten lädt Anhänge nacheinander, ein Fehler bricht alles ab (`MailModel+Draft.swift:102-105`).
7. SheetValues ohne Fundstellen. Korrektur von mir: `orbSpot` steht im Master (`ALFA Shell.dc.html:54`, `:89` als 58 %); `releaseSpan` und `pointerStep` weiter nicht gefunden.
8. Klein: deutscher Typname `MailLeadVorschlag`; zwei `purge` mit anderer Bedeutung; Schlüsselbund-Eintrag „sandbox“ bleibt; Postfach endet bei 50.
- Gegenprüfer 23.10. gegen meine Arbeit: Stück 4 (nie doppelt senden) lässt Mails unsichtbar hängen (die App hat keine Postausgang-Ansicht, IMAP legt nichts in „Gesendet“ ab); Vorschlag: `fd5c9b1` zurücknehmen, bis Design „gescheitert“ zeichnet (N42), wartet auf Johannes' Ja. „Trennen ganz oder gar nicht“ gilt nur für die Schlüssel, nicht für die Datenbank. Kleinkram: `attempted` in `HubCore.remove` überflüssig, Test wartet mit zwei `Task.yield()`.

## Mutationslauf 22.10. (Prüfungen schrumpfen statt Grenze anheben, Johannes 14.10./17.10.)
- 150 automatische Mutanten über das Kit (Operatoren aus `scripts/mutate.py`, je Mutant `swift test` in einem eigenen Worktree unter `dist/`, mit den fehlgeschlagenen Prüfzeilen als Ausgabe; die Dateien sind gelöscht, der Lauf dauert unter einer Stunde und lässt sich wiederholen): 67 gefangen, 83 überlebt (55 %). Von 280 Prüfschritten (`run*`/`step*`, 3962 Zeilen) fingen nur 50 (880 Zeilen) mindestens einen Mutanten; 230 (3082 Zeilen) keinen. Das sind Kandidaten, kein Beweis (Stichprobe, manche Mutanten gleichwertig).
- Nächster Schritt: gezielte Mutanten je Kandidat-Schritt; gestrichen wird nur, was kein Mutant rot macht oder was eine andere Prüfung schon fängt; je gestrichener Prüfung den Mutanten nennen. Worktree und Arbeitsordner am Ende löschen.
- Regel dazu (Johannes): keine neuen Prüfzeilen für Stücke ohne Fehlerweg; Grenze `testLines` bleibt 5895 (steht bei 5869); Stück 5 (Kontakte als lokale Hub-Quelle) wartet darauf.

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
