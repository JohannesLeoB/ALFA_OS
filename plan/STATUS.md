# Status

Stand 2026-10-10 23:30. Quellen: git, Johannes' Antworten (`plan/FRAGEN.md`, Abschnitt Antworten), Lesung der Fundus-Ordner durch Agenten am 10.10. (Aussagen, Stichproben vom Chef am Code geprüft). Ziel und Weg: `AGENTS.md`, Abschnitt Ziel.

## Stand
- Code hier: ALFAcolor 1.0.2 (8), notarisiert in `dist/`, Abnahme am Bild offen. Im Programm wirkt das Journal (Rückgängig nach Neustart) und die Erkennung im Code-Player. Nur im Paket, ohne Oberfläche: Sicherung, Absturzkopie, Chat, Befehlsbrücke, Stufen, Lesezeichen- und Gist-Import. Kommentare im Code widersprechen der Regel „keine Kommentare“.
- Fundus, gelesen, nicht verändert:
  - `~/ALPHA`: Build 451 (06.10.). Erreichbar nur Mail und Einstellungen (`Sources/MykilosApp/ALPHAApp.swift:172`), 15 Bereiche im `Altbestand/` (rund 56.000 Zeilen). Anbindungen im Code: Google, ClickUp, Clockodo, sevDesk, Airtable, Claude, DHL, IMAP/SMTP. Kein Kern im Sinne von ALFA: `AppState` hält alles, keine Firma als Objekt, eine Person je Mac, kein Steckbrief für Bereiche. Design-Vertrag dort: `Design/TOKENBOGEN.json` 2.3.6.
  - `~/Developer/mykilos-labor`: Vorgänger von ALPHA (65 % gleiche Pfade). `~/Developer/ARCHIV`: ältere Generationen.
  - ALFA Datan 1.0 (Preislisten → Airtable): eigene App, später Modul.
- Gestaltung: Leitlinie Werkbank (Entwurf 4), Artifact `PCkGckib5pyeWbEEAHusCF`, Kopie `gestaltung/briefing-ansichten/entwurf-4.html`. CI-Quelle ALFA Interface MASTER 1010, Artifact `G8xFQLN6yeLLRohRwZoGyi`; die Kopie `gestaltung/alfa-interface/` ist unvollständig (17 von rund 30 Bauteil-Ordnern).
- Schablone der Hülle, schwarz-weiß und bedienbar: Artifact `4iWtw8Hepr9gR9koZ5nYSG`, zur Abnahme.
- `plan/ENTSCHEIDUNGEN.md`: Arbeitsunterlage, Johannes' Wortlaut nach Thema, von ihm ungeprüft.

## Nächste Schritte
1. Schablone: Rückmeldung von Johannes einarbeiten.
2. Kern-Steckbrief als Plan ohne Code: Studio, Personen, Anbindungen (Rolle → Dienst), Orte, Module (braucht, bietet, Abgleich), eine Quelle für die Gestaltung.
3. Design-Vertrag: Entwurf, wie ALPHA-TOKENBOGEN und ALFA Interface in die eine Quelle münden; Johannes entscheidet.
4. Mail-Inventur: was Mail in `~/ALPHA` im Code wirklich kann (Datei:Zeile), als Grundlage für den ersten Bereich.
5. `plan/ENTSCHEIDUNGEN.md` auf das beim Bau Gebrauchte kürzen. Doc-Meta im Repo erst reduzieren, wenn ergründet ist, was gebraucht wird.

## Offen bei Johannes
- Abnahme der Schablone. Erster Bereich nach dem Kern.
- Abnahme am Bild für 1.0.2.
- Die ALFAcolor-Schritte vor dem 10.10. stehen in `git log -- plan/STATUS.md`; sie ruhen, bis ALFAcolor als Modul Werkzeuge an der Reihe ist.
