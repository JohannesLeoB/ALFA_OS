# Projekte · Abgleich BR ↔ ED ↔ AR

Es gibt keinen Projekte-Bogen in ED. Die sechs maßgeblichen Bögen wurden nach Projekt-Bezügen durchsucht. Einzelheiten je Kennung: `projekte.json`.

## Offene Punkte
- P1: „Filter nach Art und Phase ist im Archiv-Code nicht vorhanden. Gewünscht? Pipeline-Spalten = Phasen?“ (01-projekte.md:66)
- P2: „Ob Vorschau und Bestätigung immer kommen, ist laut Archiv eine Einstellung (Vorgabe: ja).“ (01-projekte.md:86). Diese Einstellung steht in den genannten AR-Dateien nicht.
- P3: „Die Fragen selbst gibt es nicht. Genannt sind nur Räume, Stil und Rahmen.“ (01-projekte.md:90)
- P4: „wie die Akte ohne viele Reiter gegliedert wird; das ist die Kernaufgabe für Design.“ (01-projekte.md:116)
- P5: „Welche Kacheln es geben soll, steht nirgends.“ (01-projekte.md:120)
- P11: „Lead aus einer Mail anlegen.“ (01-projekte.md:145)
- Offen für Johannes: „Fragebogen-Fragen und Aufbau des Dialogs ‚Neues Projekt‘ … Dieser Ordner ist noch nicht gelesen.“ (01-projekte.md:152)
- „Filter in der Galerie.“ (01-projekte.md:153)
- „Kacheln der Übersicht.“ (01-projekte.md:154)

## Neue Symbole
Liste laut BR: 01-projekte.md:149. Geprüft gegen `INHALT-etappe1.json` › `symbole.pfade` (57 Schlüssel, ab Z. 650) und `Icon.swift` (NEU).

| Symbol (BR) | INHALT-etappe1.json | Icon.swift | Stand |
|---|---|---|---|
| Phase/Pipeline | nicht vorhanden | nicht vorhanden | fehlt |
| Favorit (Stern) | nicht vorhanden | nicht vorhanden | fehlt |
| Archiv-Zurück | nur `archive` (INHALT-etappe1.json:658), kein Zurück | nur `archive` (Sources/Shell/Model/Icon.swift:20), kein Zurück | fehlt |
| Lead | nicht vorhanden | nicht vorhanden | fehlt |
| Nachtrag | nicht vorhanden | nicht vorhanden | fehlt |
| Wahrscheinlichkeit | nicht vorhanden (`gauge` INHALT-etappe1.json:704 ist kein benanntes Wahrscheinlichkeits-Symbol) | nicht vorhanden | fehlt |
| Aktivität | nicht vorhanden | nicht vorhanden | fehlt |
| CAD | nicht vorhanden | nicht vorhanden | fehlt |

## Bausteine
- BR nennt `OverviewTile` (01-projekte.md:119). Vorhanden: App/Components/OverviewTile.swift:5. ED nutzt es nicht; eine Übersicht ist nicht gezeichnet.
- BR nennt `ProjectFolderList` (01-projekte.md:144). Unter S/neu (App/Components) nicht vorhanden.
- Weitere Bausteine aus App/Components nennt BR nicht.
- ED nutzt an Projekt-Stellen: Bahnkopf `lane-header` mit Titel „Projekt“ (ALFA Draws.dc.html:18–19); Gruppenkopf `lhead` und Zeile `lrow` je Projekt (ALFA Atelier.dc.html:629); Menüeinträge `mi` „Projektordner (Drive)“ (ALFA Atelier.dc.html:631); Eingabefeld-Zeilen mit Zustand „fehlt“ (ALFA Draws.dc.html:430); Schriftfeld `title-block` mit Feld „Projekt“ (ALFA Atelier.dc.html:87–88).
- NEU: `apps.json` führt nur die Apps mail und settings (Resources/apps.json:8, :21); einen Bereich Projekte gibt es dort nicht.

## Projekt-Bezüge in ED
- ALFA Atelier.dc.html: PROJ (:354), Gruppierung je Projekt (:628–629), Bahnkopf-Detail = Projektname (:630), „Projektordner (Drive)“ (:631), Schriftfeld „Projekt“ (:88), Prompt-Block „Szene … Projekt“ (:548).
- ALFA Aufmass.dc.html: PROJ (:367), Gruppierung (:653–654), „Projektordner (Drive)“ (:656), Schriftfeld proj (:649, :87).
- ALFA Konfigurator.dc.html: PROJ (:337), Gruppierung (:705–707), Bahnkopf-Detail (:708), Schriftfeld leer (:701).
- ALFA Planvergleich.dc.html: Bahnkopf-Detail „Junge/Schultzendorff · 2026_017“ (:270).
- ALFA Draws.dc.html: Bahn „Projekt“ (:19, :498), Felder (:142), „aus Akte P-2041“ (:429), Schriftfeld (:256).
- ALFA Moodboard.dc.html: kein Treffer.
- BRIEFING_Editoren.md: Aufmaß trägt Projektnummer (:109); KonfigEntwurf „Projektnummer (ohne Vorgang kein Entwurf)“ (:139); Modeblatt mit Projektnummer (:274); „`.projektakte` ergibt keinen“ Modus (:240); „In die Akte“ (:169); Altprototyp „P-2026-014“ (:166); Werkzeug „neuesProjekt“ (:295).
- HANDOFF_Weiterarbeit_2110.md: „aus Akte P-2041“ als erfunden (:39).
- v-Fassungen nur genannt, nicht abgeglichen: ALFA Atelier v1, ALFA Aufmass v1, ALFA Draws v2, ALFA Moodboard v1.

## Zählung
- gezeichnet: 0
- teilweise: 0
- fehlt: 11 (P1–P11)
- erfunden: 8 (2 davon auch in HANDOFF §2 Nr. 1 und README „Erfunden“)

## Fünf wichtigste Abweichungen
1. Projektnummer: ED „aus Akte P-2041“ (ALFA Draws.dc.html:429) gegen BR „in der App `2026-014`, im Ordnernamen `2026_014`“ (01-projekte.md:25).
2. Vorschau vor dem Schreiben: BR verlangt Vorschau mit Nummer, Ordnername, Baum, Feldern, Aufgabenliste (01-projekte.md:74–79); AR-Schritt „Bestätigen“ nennt keine Vorschau (archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/GefuehrterAblauf.swift:67–69).
3. Schreibsperre: AR legt nur im Modus test an, sonst writeGateGesperrt, Ordner unter „_TEST_PROVISIONING“ (archive/before-rebuild:fundus/alpha/Sources/AlfaServices/ProjektProvisioningService.swift:57, :114); BR beschreibt das Anlegen ohne diese Sperre (01-projekte.md:80–84).
4. Lead ohne Nummer: BR „Nur als Lead … keine Nummer“ (01-projekte.md:73); AR sucht den Lead-Ordner über das Präfix der Projektnummer (archive/before-rebuild:fundus/alpha/Sources/AlfaServices/Google/ProjektLeadBeleber.swift:36–38, :51). Dazu nennt BR vier Fehler (01-projekte.md:128), AR fünf (ProjektLeadBeleber.swift:6–16).
5. Phase „Archiviert“: BR setzt beim Archivieren die Phase „Archiviert“ (01-projekte.md:123), die 7 Stufen enthalten sie nicht (01-projekte.md:30; archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/ProjectLifecycle.swift:3–11); der Deriver macht daraus „Abschluss“ (ProjectLifecycle.swift:29).

## Leseprotokoll
- br/brief-werkstatt/01-projekte.md: ganz, 154 Z.
- ed/HANDOFF_Weiterarbeit_2110.md: ganz, 83 Z.
- ed/BRIEFING_Editoren.md: ganz, 302 Z.
- ed/uebergabe-draws-IN-PROGRESS/README.md: ganz, 68 Z.
- ed/ALFA Atelier.dc.html (693 Z.): Suche per grep über alle Zeilen; gelesen Z. 84–92 und Trefferzeilen 88, 354, 376–382, 540–548, 614–631, 680, 687.
- ed/ALFA Aufmass.dc.html (721 Z.): Suche per grep über alle Zeilen; gelesen nur Trefferzeilen 87, 367, 386–393, 524–526, 609, 636, 649–656, 707.
- ed/ALFA Moodboard.dc.html (752 Z.): Suche per grep über alle Zeilen; kein Treffer.
- ed/ALFA Konfigurator.dc.html (767 Z.): Suche per grep über alle Zeilen; gelesen nur Trefferzeilen 88, 337, 363–367, 691, 701–708, 754.
- ed/ALFA Planvergleich.dc.html (398 Z.): Suche per grep über alle Zeilen; gelesen nur Trefferzeile 270.
- ed/ALFA Draws.dc.html (561 Z.): Suche per grep über alle Zeilen; gelesen Z. 14–24, 250–260, 425–435 und Trefferzeilen 108, 133–151, 270, 398, 495–498.
- ed/ALFA Atelier v1, Aufmass v1, Draws v2, Moodboard v1: nur Trefferzahl „projekt“ gezählt, nicht gelesen.
- ed/INHALT-etappe1.json (1294 Z.): Schlüssel von `symbole.pfade` per Skript; gelesen Z. 645–720; grep über alle Zeilen.
- neu/Sources/Shell/Model/Icon.swift: ganz, 95 Z.
- neu/Resources/apps.json: ganz, 31 Z.
- neu/Resources/tokens.json: nur grep, Treffer Z. 8056–8063.
- neu/App/Components: nur Dateiliste; OverviewTile.swift (115 Z.) nur grep, Z. 5.
- AR, alle ganz: AlfaKit/Domain/Project.swift 79 Z.; ProjectLifecycle.swift 33 Z.; Projektnummer.swift 51 Z.; FolderSchema.swift 114 Z.; GefuehrterAblauf.swift 174 Z.; Provisioning.swift 86 Z.; ProjektProvisioningLuecken.swift 66 Z.; ProvisioningWaechter.swift 62 Z.; ClickUpProjektMeta.swift 268 Z.; ClickUpProjektTypRoute.swift 41 Z.; ProjektAktivitaetsPuls.swift 86 Z.; CADProjektStart.swift 90 Z.; ClickUpProjectTemplate.swift 14 Z.; AlfaServices/ProjektProvisioningService.swift 194 Z.; ProjectSorter.swift 40 Z.; ProjectLifecycleStore.swift 65 Z.; ProjectWahrscheinlichkeitStore.swift 66 Z.; Google/DriveProjectFolderWatcher.swift 218 Z.; Google/ProjektLeadBeleber.swift 87 Z.
- AR, teilweise: AlfaServices/ProvisioningMode.swift Z. 1–30 von 75.
- Nicht gefunden: keine der in 01-projekte.md:5 genannten Dateien fehlt. `ProjectFolderList` (01-projekte.md:144) liegt nicht unter S/neu. Die Labor-Dateien aus 01-projekte.md:152 liegen nicht unter S.
