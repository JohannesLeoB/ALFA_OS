# HILFE-01 · Leseprotokoll

Stand 29.10.2026. Ergebnis **ungeprüft**.

## Herkunft der Quellen
- `br/` = `brief-werkstatt-2910.zip` von Johannes (`/Users/johannesleoberger/Developer/ALFA DESIGN OUTBOX/`), entpackt; Ordner darin heißt `brief-werkstatt/`. 8 Dateien, 802 Z. zusammen.
- `ed/` = Zweig `DESIGNCHANNEL` von `JohannesLeoB/ALFA_OS` (Commit `33feb10fa5244a5e979f13afaf35044d7a7b43de`), Ordner `Design Vollexport EDITOREN 2910 Transfer - Zulieferer/`. Die sechs Bögen, `HANDOFF_Weiterarbeit_2110.md`, `BRIEFING_Editoren.md` und `uebergabe-draws-IN-PROGRESS/README.md` sind byte-gleich mit Johannes' lokalem `ALFA OS Editoren Sketches 1610-3.zip` (SHA-1 verglichen).
- `ed/INHALT-etappe1.json` = `DESIGNCHANNEL`, `Design Vollexport 2910 Transfer - Etappe I/INHALT.json`; byte-gleich mit `INHALT.json` aus `ALFA OS Interface CHEF 2810 (1).zip`.
- `ar/` = Tag `archive/before-rebuild`, `fundus/alpha/Sources` (427 Dateien im Ordner insgesamt).
- `neu/` = `JohannesLeoB/ALFA_OS` `main` `f22d7bcc9e73be346ee1e13a8f691a09a9225629`: `App/Components`, `Resources/tokens.json`, `Resources/apps.json`, `Sources/Shell/Model/Icon.swift`.
- Design-Projekt `5296ce1c-…` (claude.ai/design): nicht lesbar, Antwort „project not found“.
- Hinweis: `wc -l` zählt eine Zeile weniger als im KALTSTART genannt (z. B. 154 statt 155), weil die letzte Zeile keinen Zeilenumbruch hat.

## Nicht gelesen oder nicht gefunden (gesamt)
- Sechs Bögen nur per Suche (nicht ganz) für die Bereiche Projekte, Bemusterung und die Regelprüfung aus 00-LIES-MICH. Ganz gelesen wurden die Bögen jeweils in ihrem eigenen Bereich (Aufmaß, Atelier, Moodboard, Konfigurator, Planvergleich, Draws).
- v-Fassungen (`Atelier v1`, `Aufmass v1`, `Moodboard v1`, `Draws v2`): nur genannt.
- AR `AlfaKit/Domain/InhaltsCheckoutZiel.swift`: nicht gelesen (auch im Brief nicht gelesen, 00-LIES-MICH.md:106).
- `uploads/` beider Exporte: nicht abgeglichen (laut KALTSTART). Eine Datei darin ließ sich wegen Umlaut im Namen nicht entpacken.

## Bereich projekte
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

## Bereich bemusterung
- `br/brief-werkstatt/02-bemusterung.md`: ganz, 62 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/INHALT-etappe1.json`: 640–720 von 1294 (Schlüssel `symbole`, `pfade` Z. 650–718); Schlüsselliste von `symbole.pfade` per Skript ganz (57 Einträge).
- `ed/ALFA Atelier.dc.html` (693 Z.), `ALFA Aufmass.dc.html` (721 Z.), `ALFA Moodboard.dc.html` (752 Z.), `ALFA Konfigurator.dc.html` (767 Z.), `ALFA Planvergleich.dc.html` (398 Z.), `ALFA Draws.dc.html` (561 Z.): nicht ganz gelesen. Alle Zeilen per Skript nach Stichwörtern durchsucht (bemuster, muster, swatch, materia, probe, farbton, sample, vorgeschlagen, gezeigt, gewählt, abgelehnt, bestellt, medienkatalog, papers, EAN, hersteller, warenkorb, checkout, zuordnen, manuell, katalog, mediathek). Einzeln gelesen: Konfigurator Z. 345, 346, 360, 492–500, 565; Atelier Z. 217, 354–361; Planvergleich Z. 148.
- v-Fassungen (`ALFA Atelier v1`, `ALFA Aufmass v1`, `ALFA Moodboard v1`, `ALFA Draws v2`): nur genannt, nicht abgeglichen.
- `ed/BRIEFING_Editoren.md` (302 Z.): nicht gelesen.
- AR ganz gelesen: `AlfaKit/Domain/Bemusterung.swift` (150 Z.), `AlfaServices/Database/BemusterungStore.swift` (95 Z.), `AlfaKit/Domain/CheckoutZiel.swift` (70 Z.), `AlfaKit/Domain/GefuehrterAblauf.swift` (174 Z.).
- AR nur Suchtreffer: `AlfaServices/AssistantLeseWerkzeuge.swift:141-178` (ListBemusterungTool), `AlfaServices/AssistantTool.swift:1652,1680`, `AlfaServices/Database/VolltextSucheStore.swift:28-29`, `AlfaServices/Database/GRDBDatabase.swift:761-762`, `AlfaKit/Domain/VolltextTreffer.swift:12,20,28`, `AlfaKit/Domain/Konfigurator/KonfigMaterial.swift:87-134`.
- AR nicht gelesen: `AlfaKit/Domain/InhaltsCheckoutZiel.swift` (127 Z.; Suche „bemuster“: kein Treffer), `AlfaServices/Airtable/PapersKatalogStore.swift` (211 Z.).
- NEU: `Sources/Shell/Model/Icon.swift`: Z. 3–64 gelesen, 65–95 nur Suchtreffer. `App/Components/*.swift` und `Resources/apps.json`, `Resources/tokens.json`: nur Suche swatch|palette|bemuster|sampling, kein Treffer.

## Bereich aufmass
- `br/brief-werkstatt/03-aufmass.md`: ganz, 107 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Aufmass.dc.html`: ganz, 722 Z. (in vier Abschnitten 1–175, 176–375, 376–554, 555–722)
- `ed/ALFA Aufmass v1.dc.html`: nicht gelesen (nur genannt)
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/BRIEFING_Editoren.md`: nur Trefferzeilen zu „aufma|survey|laser|disto“ (u. a. 20, 34–35, 40, 46, 51–52, 98–99, 104–127, 135, 140, 170, 207–208, 214, 222, 226, 230–232, 240–258, 300–301) von 302
- `ed/INHALT-etappe1.json`: nur `symbole.pfade`, Z. 645–712 von 1294, dazu Trefferzeilen 104, 254, 415, 455, 717
- `neu/Sources/Shell/Model/Icon.swift`: Fallzeilen 4–9, 13–64, 70–94 von 95 (Treffer auf „case|static“)
- `neu/App/Components/*.swift`: nur Dateinamen (33 Dateien), Inhalt nicht gelesen
- `neu/Resources/tokens.json`, `neu/Resources/apps.json`: nicht gelesen
- Archiv `ar/fundus/alpha/Sources/`:
  - `AlfaKit/Domain/AufmassModell.swift`: ganz, 265 Z.
  - `AlfaKit/Domain/AufmassLayer.swift`: ganz, 201 Z.
  - `AlfaKit/Domain/AufmassAutoBemassung.swift`: ganz, 111 Z.
  - `AlfaKit/Domain/AufmassPerspektive.swift`: ganz, 198 Z.
  - `AlfaKit/Domain/AufmassViewport.swift`: ganz, 65 Z.
  - `AlfaKit/Domain/AufmassDokument.swift`: ganz, 55 Z.
  - `AlfaKit/Domain/AufmassDateiname.swift`: ganz, 55 Z.
  - `AlfaKit/Domain/LaserMeasuring.swift`: ganz, 16 Z.
  - `AlfaKit/Domain/LaserDiagnose.swift`: ganz, 69 Z.
  - `AlfaServices/Aufmass/LeicaDistoBluetoothAdapter.swift`: ganz, 150 Z.
  - `AlfaServices/Aufmass/LaserGeraeteProfil.swift`: ganz, 50 Z.
  - `AlfaServices/Aufmass/LaserDiagnoseScanner.swift`: ganz, 162 Z.
  - `AlfaServices/Database/AufmassEntwurfStore.swift`: ganz, 27 Z.
  - `AlfaKit/Domain/FolderSchema.swift`: Z. 25–45 (Länge nicht ermittelt)
  - `AlfaKit/Domain/GefuehrterAblauf.swift`: Z. 130–155 (Länge nicht ermittelt)
- Nicht gefunden: keine Datei. Im Archiv gibt es keine Stelle für „Übernehmen/Verwerfen je Auto-Vorschlag“, „Löschen mit Rückgängig“ und die Fotoquellen „Datei, Projektordner“; gesucht wurde nur in den oben gelesenen Dateien.

## Bereich atelier
- `br/brief-werkstatt/04-atelier.md`: ganz, 101 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Atelier.dc.html`: ganz, 693 Z.
- `ed/ALFA Atelier v1.dc.html`: nicht gelesen (nur genannt).
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/BRIEFING_Editoren.md`: ganz, 302 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/INHALT-etappe1.json`: Z. 645–712 von 1294 (Schlüssel `symbole.pfade` ganz, 57 Einträge per Skript gezählt).
- `neu/Sources/Shell/Model/Icon.swift`: ganz, 95 Z.
- `neu/App/Components/*.swift`: nur Dateinamen und Zeilenzahlen, kein Inhalt gelesen.
- `neu/Resources/tokens.json`, `neu/Resources/apps.json`: nicht gelesen (für diese Aufgabe nicht gebraucht).
- AR `AlfaKit/Domain/Skizze/`: `SkizzenModell.swift` ganz 213 Z., `SkizzenLayer.swift` ganz 63 Z., `MaterialSlot.swift` ganz 80 Z., `PlatziertesBild.swift` ganz 98 Z., `SkizzenMasse.swift` ganz 38 Z., `PerspektivRaster.swift` ganz 160 Z., `SkizzenGeometrie.swift` ganz 105 Z., `Verlaufsstapel.swift` ganz 54 Z., `PromptKompilierer.swift` ganz 73 Z., `PromptVorlagen.swift` ganz 31 Z., `RenderCheckout.swift` ganz 158 Z.
- AR `AlfaServices/Database/SkizzeEntwurfStore.swift`: ganz, 72 Z.
- AR `AlfaKit/Domain/Konfigurator/KonfigMaterial.swift`: Z. 155–180 von 200; dazu grep nach Beispielnamen.
- Alle in BR 04-atelier.md:6-7 genannten Archivdateien gefunden; keine fehlt.

## Bereich konfigurator
Gelesen:
- `AUFTRAG-TEIL.md`: ganz, 49 Z.
- `br/brief-werkstatt/05-konfigurator.md`: ganz, 150 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Konfigurator.dc.html`: ganz, 767 Z.
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/BRIEFING_Editoren.md`: 129–200 von 302 (dazu Suchtreffer).
- `ed/INHALT-etappe1.json`: 645–712 von 1294 (dazu Suchtreffer für `alert`, `list`, `pen`).
- `neu/Sources/Shell/Model/Icon.swift`: ganz, 95 Z.
- `neu/Resources/apps.json`: ganz, 31 Z.
- `neu/App/Components/`: nur Dateinamen (33 Dateien), kein Inhalt.
- `ar/fundus/alpha/Sources/AlfaKit/Domain/Konfigurator/KonfigModell.swift`: ganz, 455 Z.
- `…/Konfigurator/KonfigRegeln.swift`: ganz, 239 Z.
- `…/Konfigurator/KonfigKuerzel.swift`: ganz, 77 Z.
- `…/Konfigurator/KonfigMaterial.swift`: ganz, 200 Z.
- `…/Konfigurator/KonfigArchetypen.swift`: ganz, 175 Z.
- `…/Konfigurator/KonfigAnfrageText.swift`: ganz, 133 Z.
- `…/Konfigurator/KonfigRenderPrompt.swift`: ganz, 91 Z.
Nicht gelesen oder nicht gefunden:
- `neu/Resources/tokens.json`: nicht gelesen.
- Typen `StilPreset`, `KompilierterPrompt`, `MaterialRef` (genutzt in `KonfigRenderPrompt.swift:4`, `KonfigMaterial.swift:165`): Datei nicht gesucht, nicht gelesen. „fünf Blöcke wie im Atelier“ (`05-konfigurator.md:131`) daher nur gegen `KonfigRenderPrompt.swift:10–16` geprüft.
- `S/zip-ed/`: vorhanden, nicht gelesen (keine Quelle laut Auftrag).

## Bereich plan
Gelesen:
- `AUFTRAG-TEIL.md`: ganz, 49 Z.
- `br/brief-werkstatt/06-plan.md`: ganz, 59 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Planvergleich.dc.html`: ganz, 398 Z.
- `ed/ALFA Draws.dc.html`: ganz, 561 Z.
- `ed/ALFA Draws v2.dc.html`: nur Zeilenzahl (418 Z.), Inhalt nicht gelesen.
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/BRIEFING_Editoren.md`: 129–200 von 302 (dazu Suchtreffer).
- `ed/INHALT-etappe1.json`: 645–712 von 1294 (dazu Suchtreffer).
- `neu/Sources/Shell/Model/Icon.swift`: ganz, 95 Z.
- `neu/Resources/apps.json`: ganz, 31 Z.
- `neu/App/Components/`: nur Dateinamen (33 Dateien).
- `ar/fundus/alpha/Sources/AlfaKit/Domain/PlanDokument.swift`: ganz, 108 Z.
- `ar/…/Domain/PlanProjektion.swift`: ganz, 133 Z.
- `ar/…/Domain/PlanTransform.swift`: ganz, 60 Z.
Nicht gelesen oder nicht gefunden:
- `ar/fundus/alpha/Sources/AlfaServices/Google/PlanCollector.swift`: gefunden, nicht gelesen (BR nennt die Datei nicht).
- Aufmaß-Archiv (für „Vorgabe wie im Aufmaß“, `06-plan.md:17`): nicht gelesen, daher unklar.
- `alfa-draws.css`, `draws.tokens.json`, `ERFUNDEN_DRAWS-ABLAEUFE.md`: nicht unter `S/ed/`; vorhanden unter `S/zip-ed/`, nicht gelesen (keine Quelle laut Auftrag).
- `neu/Resources/tokens.json`: nicht gelesen.

## Bereich moodboard
- `br/brief-werkstatt/07-moodboard.md`: ganz, 53 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Moodboard.dc.html`: ganz, 752 Z.
- `ed/ALFA Moodboard v1.dc.html`: nicht gelesen (nur genannt).
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/BRIEFING_Editoren.md`: ganz, 302 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/INHALT-etappe1.json`: Z. 645–712 von 1294 (Schlüssel `symbole.pfade` ganz).
- `neu/Sources/Shell/Model/Icon.swift`: ganz, 95 Z.
- `neu/App/Components/*.swift`: nur Dateinamen und Zeilenzahlen, kein Inhalt gelesen.
- `neu/Resources/tokens.json`, `neu/Resources/apps.json`: nicht gelesen.
- AR `AlfaServices/Airtable/PapersKatalogStore.swift`: ganz, 211 Z.
- AR `AlfaKit/Domain/PapersAssetAbgleich.swift`: ganz, 54 Z.
- AR `AlfaKit/Domain/CheckoutZiel.swift`: ganz, 70 Z.
- AR `AlfaKit/Domain/Skizze/PlatziertesBild.swift`: ganz, 98 Z.
- AR `AlfaKit/Domain/FolderSchema.swift`: Z. 40–56 von 114.
- AR `AlfaKit/Domain/GefuehrterAblauf.swift`: Z. 80–98 von 174.
- AR `AlfaKit/Domain/Konfigurator/KonfigModell.swift`: Z. 300–325 von 455 (QuellenStand mit moodboardStand :310).
- AR `AlfaKit/Domain/InhaltsCheckoutZiel.swift`: nicht gelesen (127 Z.).
- AR `AlfaServices/Google/DriveFolderCategory.swift`: nur grep-Treffer Z. 26.
- In BR 07-moodboard.md:14 genannte Archivdateien gefunden; keine fehlt.

## Bereich lies-mich
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `br/brief-werkstatt/02-bemusterung.md`: ganz, 62 Z.
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- Sechs Bögen nicht ganz gelesen: `ALFA Atelier.dc.html` (693 Z.), `ALFA Aufmass.dc.html` (721 Z.), `ALFA Moodboard.dc.html` (752 Z.), `ALFA Konfigurator.dc.html` (767 Z.), `ALFA Planvergleich.dc.html` (398 Z.), `ALFA Draws.dc.html` (561 Z.). Alle Zeilen per Skript geprüft: (1) Textknoten im Markup mit ≥ 3 Wörtern; (2) String-Literale hinter `text|sub|tip|assist|hint|toastIt|label|note|title|placeholder` mit ≥ 5 Wörtern oder Satzende; (3) Stichwörter zu Firmenname, Ordnern, Phasen, Material, Vorlagen, Anrede, Beispiel/Demo, `confirm(`/`prompt(`, `off:`, `z-index`, Textschlüssel. Einzeln gelesen: Konfigurator Z. 345, 346, 360, 492–500, 565; Atelier Z. 217, 354–361; Planvergleich Z. 148, 177, 255, 276; Aufmass Z. 386. Erklärsätze in String-Verkettungen ohne diese Schlüssel können der Suche entgangen sein.
- `ed/BRIEFING_Editoren.md` (302 Z.), `ed/alfa-bausteine.js` (131 Z.): nicht gelesen.
- v-Fassungen: nicht gelesen.

