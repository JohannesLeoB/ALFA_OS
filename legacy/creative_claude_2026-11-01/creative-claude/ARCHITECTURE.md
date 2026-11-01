# Creative Claude – Architektur (Arbeitstitel)

Stand 30.10.2026 · Status **Entwurf, nicht freigegeben** · Zielsystem ALFA OS (Paket `ALFA`), Design-Master 2026-10-28 (ALFA-Uebergabe-2810).
Dieses Dokument liegt außerhalb des ALFA-Repos. Bau in ALFA erst auf Wort des Owners; bis dahin ist jeder Abschnitt Vorlage, kein Auftrag.

## 0 Für Agents

Zweck: Claude baut 3D-Küchen in Autodesk Fusion. Ein firmenneutraler **Kern** liefert Verfahren; ein **Profil** je Firma oder Nutzergruppe liefert Werte, CI und Vorlagen. Profile, Quellordner, Vorlagen und Beispielpläne pflegt der Nutzer in ALFA → HUB → Einstellungen.

Leitwörter:
- **Kern** kennt Verfahren, **Profil** kennt Werte (Test: ändert sich der Wert zwischen zwei Firmen → Profil).
- **Zweck**: jede Datei hat genau einen `purpose` und wird nur dafür gelesen.
- **Beleg**: jede Regel trägt Status `bemasst` / `abgeleitet` / `annahme` und Quelle + Seite.
- **Freigabe**: gelesen wird nur, was der Nutzer ausdrücklich freigibt; Widerruf jederzeit.
- **Bogen**: UI entsteht nur aus dem gültigen Design-Master; fehlt der Bogen, hält der Bau an und meldet Bedarf.

Lesereihenfolge: §1 Einbettung (wo im Code) → §2 Oberfläche (was im HUB) → §3 Fachkern (was das Modul tut) → §4 Entscheidungen (was der Owner klärt) → §5 Wissenspaket Küche (eigene Datei `wissenspaket/KAPITEL_WISSENSPAKET.md`: Konzept, Datenmodell, Code-Design, Stufenplan).
Namensregel: keine Personen-, Kunden-, Firmen- oder Lieferantennamen; Rollen statt Namen (Owner, Kunde, Lieferant A/B), Projekte als Runde 1, 2, ….
Belegform: `Datei:Zeile`; „Vorschlag:“ = eigener Entwurf; „offen“ = Quellen klären es nicht.

Quellen dieses Entwurfs (je vollständig gelesen): ALFA `AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `Package.swift`, `project.yml`; Master 2810 (Pflichtdateien in §2); Handoff Fusion-Küchen-Session; Trainingsrunde 1 (Küchenplan, 4 S.); SVG-Planbibliothek `README.md`; Musterdaten `LIESMICH.txt`.

## 1 Einbettung in ALFA OS

Belegkürzel: A = AGENTS.md, C = CLAUDE.md, R = ARCHITECTURE.md, P = Package.swift, Y = project.yml, E = entwurf_v0.md. „Vorschlag:“ = eigener Entwurf, kein ALFA-Beleg.

### 1.1 Sitz im Paketaufbau
- Paket `ALFA`, Swift 6.2, macOS 26, jedes Target `strict` (Warnungen = Fehler, Sprachmodus 6) (P:1-6, P:10-11).
- 15 Library-Module, ein Testtarget je Modul; Tabelle R:7-23 ist die vollständige Kantenliste (R:5, R:25).
- Integrationen: `Sources/Integrations/<Service>`, hängen von `Hub` + `Assistant` ab, nie voneinander; sie treffen sich in `App` (R:25, R:36, P:66-71, P:123-164).
- Persistierende Integrationen (zwei bestehende Targets): `Hub, Assistant, Storage, GRDB` (P:147-152) bzw. `Core, Hub, Assistant, Storage, GRDB` (P:153-158).
- Modulnamen sind geprüft: Core, Design, Shell, Storage, Hub, Assistant, Mail, Calculation, Catalog, Project, Today, Survey + Integrationen; Creative steht nicht darin (R:43).
- Ein Modul hat nur die Ordner `Model, Logic, Port, Adapter, State, Store, Tool`, keine Dateien direkt (check) (R:44, R:47-55, A:7).
- `Tool/` gehört nur Assistant (check) (R:55). Views: `App/<Feature>/` (R:34); Hub enthält keine SwiftUI-Views (R:25).
- Ebenen: `State, Tool → Port, Logic, Model`; `Store, Adapter → Port, Model`; `Logic → Model` (R:97-101).
- Port liegt im konsumierenden Modul, wenn das implementierende davon abhängt; Beispiel `MailSearchPort` in Assistant, `MailSearchClient` in Google (R:106).
- Composition Root: `App/Shell/Assembly.swift`; `ToolShelf` baut Integrations-Clients und -Stores; `Assembly.reshelve()` baut die Registry bei Inlet-Wechsel neu (R:110).
- Vorschlag: Target `Creative` in `Sources/Integrations/Creative`; Tests `Tests/CreativeTests/CreativeTests.swift` (R:37, R:81).
- Vorschlag: Abhängigkeiten `Core, Hub, Storage, GRDB`; `Assistant` nur, wenn Lernschleife dessen Claude-Zugang nutzt (siehe 1.2).
- Vorschlag Zuordnung v0 → Ordner (E:14):

| v0 | ALFA-Ort | Beleg Regel |
|---|---|---|
| Model (profile, source, asset, rule, job) | `Model/` Werttypen ohne I/O | R:49 |
| Store (GRDB) | `Store/…Store` | R:54, R:116 |
| Ingest (Formate) | `Parser` (Logic/Adapter) + Datei-I/O in `Adapter/` | R:51, R:70 |
| Learn (Regelvorschläge) | `Logic/…Engine`; Modellaufruf über `ClaudeClient` | R:50, R:131 |
| Render (Vorlage + Daten → SVG) | `Logic/…Engine`; PDF-Ausgabe in `Adapter/` | R:50-51 |
| Bridge/Fusion | `Port/FusionPort` + `Adapter/FusionClient` | R:51, R:65 |
| UI-Zustand | `State/` (I/O nur über Ports) | R:53 |
| Views | `App/Settings/` | R:34 |

- Ordner `Ingest, Learn, Render, Bridge` entfallen (R:44).

### 1.2 Hub-Anbindung
- Hub → Einstellungen: Gruppen Ich, Firma, Dateiordner, Verbindungen, Schutz, System (R:282).
- Dienste sind Katalogeinträge in `Sources/Hub/Store/IntegrationCatalogStore.swift`: Beispiele: ein Versanddienst (eine Kachel, Felder Schlüssel/Secret), ein Speiseplan-Dienst (Schlüssel) (R:295-296).
- Kachel `App/Settings/IntegrationList.swift`, Karte `IntegrationCard.swift`: Zeilen Zustand, Anmeldung, Feldwerte, Abgleich mit `Cadence` (R:288-291, R:332-336, R:352-358).
- Listeninhalte haben eigene Blöcke: `AccountBlock` (Konten), `SignatureBlock`, Vorlagenliste in `SettingsDetail` (R:337-350, R:377). Profil-/Quellenlisten folgen diesem Block-Muster, Formen aber erst nach Master.
- Verdrahtung: `Assembly` baut `ProviderPort`-Liste und `Connections`; `ToolShelf` registriert Assistant-Tools nur für verbundene Inlets (R:110).
- Zugangsdaten: `KeychainStore`, nie die Datenbank; `ClaudeCredential` (Hub) liest den Slot des Inlets `claude` (R:116, R:131).
- Vorschlag: Creative erscheint als Katalogeintrag in `IntegrationCatalogStore` (Gruppe offen); Profile, Quellen, Regeln in eigenen Blöcken der Karte.
- Vorschlag: Assistant-Tools für Creative nach dem `MailSearchPort`-Muster – Port in Assistant, Implementierung in Creative, Registrierung in `ToolShelf` (R:106, R:110).
- Lernschleife: `ClaudeClient` (Assistant) ruft die Anthropic-API (R:131); Datenschutzschalter `PrivacyCategory`: mail, calendar, contacts, drive, clickUp, notes, tasks, catalogCalculation, studioKnowledge, chat, time (R:134).
- `ModelRouter` und Berechnungszahlen bleiben unverändert (C:24, R:135).
- Datei- und Netzzugriff von Learn nur über `Adapter`/`Store` hinter Ports (R:104).
- Vorschlag: Regelvorschläge bleiben Daten mit Status, bis der Nutzer bestätigt (E:8).

### 1.3 Persistenz, Sandbox, Dateien, Netz
- Eine SQLite-Datei `alfa.sqlite` in Application Support `ALFA_OS`, WAL, Foreign Keys an, geöffnet von `DatabaseStore` (R:114).
- Migrationen: `SQLiteStore+Migrations.swift` und `+CalculationMigration.swift`, je Modul bzw. Integration eine benannte Migration (Liste R:115); laufen beim Öffnen (R:115).
- Jeder datenbankgestützte Store erhält `SQLiteStore` über den Initializer (R:116).
- Vorschlag: Migration `creative` (Tabellen profile, source, asset, rule, job nach E:17); Bookmark-Daten als Blob in `source`, kein Secret.
- Dateien neben der DB: Ordner `attachments` für Chat-Anhänge (R:119). Vorschlag: gleiches Muster für abgeleitete Creative-Dateien.
- Sandbox: `ENABLE_APP_SANDBOX: YES`, Hardened Runtime an (Y:14, Y:90).
- Netz: `ENABLE_OUTGOING_NETWORK_CONNECTIONS: YES`; eingehende Verbindungen sind in `project.yml` nicht gesetzt (Y:91).
- Netz-I/O gehört in `Adapter/…Client` (R:51, R:65, R:104).
- Entitlements-Datei `Resources/ALFA_OS.entitlements` (Y:89); Inhalt nicht Teil der Quellen.
- Quellordner im UI: Gruppe Dateiordner, „Projektordner“, „Ordnerschema“ mit Projektordner/Projektdaten/Vorlagen existieren schon (R:359, R:375, R:377).
- Gebündelte Resources sind in `project.yml` einzeln gelistet (Fonts, Assets, Localizable.xcstrings, apps.json) (Y:26-35).
- Externe Abhängigkeit: nur GRDB 6.29.3 (R:5, P:29-31).
- Firmenwerte und Firmenname bleiben außerhalb von Swift, sie kommen aus der Firmenkonfiguration; Beispiel `Resources/company.example.json` (A:17, R:88, C:32).

### 1.4 Regeln für jeden Bau-Agent
- Benennung: Englisch, ASCII, CamelCase, kein Modulpräfix (A:14, R:60).
- Verbotene Namenswörter: Manager, Helper, Util, Service, Handler, Impl, Base, Common, Misc, New, Old, Versionszahlen, Endziffern (check) (A:9, R:61).
- Rollen-Suffix bestimmt Ordner: Client → Adapter, Engine → Logic, Store → Store, Port → Port, State → State, Failure → Model (check) (A:7, R:64-78).
- Starke Dateien: Dateiname = Haupttyp samt Nebentypen, 200–600 Zeilen, max. 800 (check); keine Ein-Typ-Krümel (A:8, R:45, R:59).
- Ein Protokoll je Port-Datei (R:51).
- View-Namen nach der Sache (`ProfileList`); in `Sources` keine View-Suffixe, in `App` keine Suffixe Client/Store/Engine/Router/Parser/Registry/Tool/Port/Failure (check) (R:79-80).
- Keine Kommentare, keine Prosa im Code; Texte als Keys in `Resources/<name>.localizable.json` (de, optional en), Merge via `utils/merge_strings.py` (A:15, R:85-86, R:127).
- Views: Farben, Größen, Abstände aus `Design`-Tokens oder `App/Design/SheetValues.swift`; Literale nur 0, 1, 2 (A:16, R:87).
- `internal` als Standard, `public` nur modulübergreifend mit Aufrufer; kein Code ohne Aufrufer; keine Stubs (A:10, R:91).
- Views nur aus dem gültigen Design-Master (`DESIGN/ALFA Design Master 2026-10-28.zip`); fehlt der Bogen, hält die Aufgabe an und meldet es (A:23, C:21).
- Design-Aufträge laufen über DESIGNCHANNEL, erst nach Bestätigung durch den Owner (C:40).
- Dateien vor jeder Änderung vollständig lesen; keine pauschalen Schnitte; vor Löschen nicht bewiesenen toten Codes fragen (A:22, C:22).
- Tests: je Modul genau `Tests/<Module>Tests/<Module>Tests.swift` (check) (R:81).
- Vor Commit grün: `python3 -I utils/check.py` und `zsh utils/check_modules.sh` (A:24).
- Build-Ort: `swift build` und `xcodegen` laufen nur im Terminal des Owners, nicht in der Claude-Sandbox; Keychain-/Atomic-Write-Tests erscheinen dort als `sandbox-skipped` (C:46-48).
- Sandbox blockiert → Einschränkung melden, Produktivcode unverändert lassen (A:30).
- Commit: Betreff ≤ 72 Zeichen, ≤ 3 Zeilen Body, letzte Zeile exakt die Signaturzeile aus A:26; Push nach `main`, Historie nur vorwärts (A:25-26).
- Dokumente: nur `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md` (check) (A:18, R:89).
- Jede weitere Datei (md, tsv, txt, sonstige Docs), auch gitignored oder lokal, nur nach dem Wortlaut „ja schreib“ des Owners (C:7).
- `CLAUDE.md` ändert sich nur auf Wort des Owners (C:41).
- Tokens und Texte: generierte Dateien müssen zu den Generatoren passen (check) (R:90, R:123).

### 1.5 Korrekturen zu Entwurf v0
- `AlfaKit/` existiert nicht; das Paket heißt `ALFA` (P:10, E:13).
- `Hub/Integrations/CreativeClaude/` existiert nicht; Integrationen liegen in `Sources/Integrations/<Service>`, Views in `App/` (R:34, R:36, E:13).
- `ProfileListView`, `ProfileDetailView`, `RuleReviewView` → `ProfileList`, `ProfileDetail`, `RuleReview`; View-Suffix nur bei gleichnamigem Modell (R:79, E:13).
- `Ingest/Learn/Render/Bridge` sind keine erlaubten Modulordner (R:44, E:14).
- `profil.yaml`, Mustache, IDML brauchen Parser; zulässige externe Abhängigkeit ist nur GRDB; YAML/Mustache-Pakete wären neue Abhängigkeit (R:5, E:7).
- Vorschlag: Profilwerte als JSON (Muster `company.example.json`) oder DB-Zeilen statt YAML (C:32).
- Seeds/Beispielpläne/Vorlagen im Repo wären Dokumente → nur nach „ja schreib“; Daten bleiben in Nutzerordnern (C:7, E:7).
- „Seed“ ist in Calculation als Preisanker belegt (`calc.seed.supplier`); Namenskollision bei „Seeds“ (C:55, R:136, E:3).
- „CreativeClaude“ als Typpräfix entfällt (R:60).
- Creative steht in `CLAUDE.md` weder unter Decisions noch unter Next tasks; Aufnahme nur auf Wort des Owners (C:19-60, C:41, C:60).
- „Bau nur nach ALFA-Regeln“ (E:20) präzisieren: UI erst nach Master (A:23); Modulname steht nicht in der geprüften Liste (R:43).

### 1.6 Offen (ALFA-Quellen klären es nicht)
- Modulname und -ort: `Creative` neben dem reservierten Editoren-Modul (Survey, „creative suite“) (R:43, C:29).
- Aufnahme in die Modulnamen-Prüfung von `utils/check.py`, in die Tabelle R:7-23 und in `project.yml`-Dependencies (R:43, Y:36-66).
- Datei-Zugriff: Security-scoped Bookmarks und Entitlements `user-selected`/`bookmarks` – ALFA nennt kein Muster; Inhalt der Entitlements-Datei fehlt (Y:89).
- Fusion-Kopplung: localhost-Client (ausgehend gesetzt) oder Übergabeordner; Add-in-Server bräuchte eingehende Verbindung, nicht gesetzt (Y:91, E:20).
- Heimat von Python-Bausteinen/Fusion-Add-in: Layout kennt nur `utils/` für Skripte (R:41).
- Genaue Signatur und Zweck von `ProviderPort` und `Connections` (Mail-Provider oder allgemein); nicht beschrieben (R:110, R:347).
- Modul der Dateien `SQLiteStore+Migrations.swift` und `DatabaseStore`; nicht genannt (R:114-115).
- Gruppe in Einstellungen für Creative (Verbindungen oder Dateiordner) und Bogen für Profil-/Regel-Blöcke; Register kennt nur Mail und Settings, keinen Creative-Bogen (R:147, R:282).
- Datenschutzkategorie für Quelldateien an Claude: bestehende Kategorie oder neue; Entscheidung des Owners (R:134, C:56).
- Ob `ClaudeClient` öffentlich nutzbar ist und Token-Verbrauch zählt (`UsageBlock`) (R:131, R:356).
- Überschneidung mit vorhandener Vorlagenliste in Einstellungen (R:377).
- DWG-Lizenz, Font-Lizenz, DWG-Konverter (E:20).
- Zählung der Module: `CLAUDE.md` nennt 14, `ARCHITECTURE.md` fünfzehn (C:11, R:5).

## 2 Oberfläche: HUB → Einstellungen → Creative Claude

Belege: `Datei:Zeile`, Pfade relativ zu `ALFA-Uebergabe-2810/` (`project/` = ALFA Einstellungen.dc.html, SPEC.md, HANDOFF.md, PROJEKT-REGELN.md, entscheidungen.md; `contract/` = components.json, views.json, texts.json; `project/lieferung-an-code/` = settings-sections.json, START-CODE-2810.md). Eigenes ist mit „Vorschlag:“ markiert, Ungeklärtes mit „offen“. Bauteil-`where` stimmen auf Part-Ebene mit dem Bogen (START-CODE-2810.md:18); die `where` der Elemente weichen bis 6 Zeilen ab (components.json:469–476 gegen ALFA Einstellungen.dc.html:92–94).

### 2.1 Aufbau von Einstellungen im Master 2810
| Ebene | Master (IDs) | Beleg |
|---|---|---|
| Hülle | Einstellungen läuft in `ALFA Shell` (Blob, Sync, drei Bahnen, Griffe); Hülle gilt für alle Ansichten identisch | ALFA Einstellungen.dc.html:13; PROJEKT-REGELN.md:3–5 |
| Links | `settings.lane-header`, `settings.list-row`, `settings.mark`, `settings.counter`; Zeilen = Gruppen | ALFA Einstellungen.dc.html:16,25–28,387–391 |
| Gruppen im Bogen | Ich (person), Firma (building), Dateiordner (folder), Verbindungen (plug), Schutz und System (system) | ALFA Einstellungen.dc.html:231 |
| Einträge je Gruppe | Ich: profil, darstellung (+start, sperre); Firma: firma; Dateiordner: einrichtung, vorlagen; Verbindungen: Dienste (SVC) + schluessel; Schutz und System: datenschutz, diagnose, impressum | ALFA Einstellungen.dc.html:239,241,345 |
| Mitte, nur Verbindungen | `settings.settings-tiles` > `settings.tile-group` > `settings.tile-grid` > `settings.settings-tile`; Gruppen „Integrationen“, „Schlüssel“; Initial oder Logo im Ring | ALFA Einstellungen.dc.html:47,400–404; SPEC.md:72 |
| Mitte, sonst | `settings.message-row` + `settings.list-section-header`; unter Ich zusätzlich `settings.profile-tile` | ALFA Einstellungen.dc.html:50,55–58,416 |
| Rechts | genau eine Karte `settings.card-2` mit `settings.card-content`, ohne Kopf; Kopfzeile der Bahn `settings.lane-header-3` mit `settings.command-group` | ALFA Einstellungen.dc.html:85–98,250; SPEC.md:33 |
| Kartenblöcke | `settings.service-hero`, `settings.list-section-header-3`, Hinweiszeile (isNote), `settings.card-notice`, `signature-editor`, `settings.field-row` | ALFA Einstellungen.dc.html:100–113 |
| field-row-Slots | `connection-status`, Eingabe, Wert, `choice` (Pille + Menü), `segmented-control`/`option`, `confirm`, `toggle`, `text-button` | ALFA Einstellungen.dc.html:119–130 |
| Overlays | `settings.toast` (Rückgängig bzw. Erneut versuchen), `settings.anchored-menu` mit `settings.menu-row` | ALFA Einstellungen.dc.html:170,174,178 |
| Schmale Karte (<480) | Segmente werden Pille, mehrere Knöpfe werden „Aktionen“-Menü | ALFA Einstellungen.dc.html:457–462 |
| Aktionen | chooseOption `settings.choice.pill-go`, switchOption `settings.toggle.toggle`, addAccount, createTemplate (hold), removeAccount `confirm.confirm-open.open-ask` (hold), undoLast | views.json:197–245 |
| Hold-to-confirm | `confirm`, `confirm-pill`, `confirm-open`, `confirm-yes`, `confirm-no`, `confirm-undo` (approved-provisional) | components.json:928,945,1009,1027; SPEC.md:75 |
| Texte | Schlüssel `settings.<kind>.sNNN`, de+en, status set-by-design | texts.json:1290–2243 |

### 2.2 Abweichungen im Master (Build-Agent meldet, entscheidet nicht)
- Gruppen: Bogen hat 5 (Dateiordner eigene Gruppe), settings-sections.json und SPEC.md haben 4 (Dateiordner und Vorlagen liegen dort als Abschnitte unter Firma). Belege: ALFA Einstellungen.dc.html:231; settings-sections.json:26–51; SPEC.md:32. Stand: Bogen 2026-10-19 (:4), settings-sections.json 2026-10-18 (:2). Maßgeblich ist der Bogen; offen bis Design bestätigt.
- views.json führt für Einstellungen noch `card-stack` (views.json:191), der Bogen öffnet genau eine Karte (ALFA Einstellungen.dc.html:250; SPEC.md:33). Maßgeblich: eine Karte.
- `settings-tile` misst Höhe `{size.menuRowHeight}` (components.json:2627–2630), der Bogen nutzt `--size-settingsTileHeight` 112 (ALFA Einstellungen.dc.html:47; components.json:3065–3067; SPEC.md:72). offen: Vertrag korrigieren lässt Design.
- Dienste (SVC: Felder, Abgleich, Extras) liegen in `alfa-bausteine.js`, nicht im Paket gelesen (ALFA Einstellungen.dc.html:208,312–321). offen: SVC-Schema für einen neuen Eintrag.

### 2.3 Vorschlag: Platz von Creative Claude
- Vorschlag A (nutzt nur vorhandene Mechanik): neue Gruppe „Creative Claude“ in der linken Bahn (CATS), fünf Einträge in der Mitte als `settings.message-row` (Profile, Quellen, Vorlagen & CI, Seeds, Regelprüfung), je eine Karte rechts aus Blöcken (wie `blocks(id)`). Beleg Mechanik: ALFA Einstellungen.dc.html:231,239,297,326. Abweichung: SPEC.md:32 nennt vier Gruppen.
- Vorschlag B: eine Kachel „Creative Claude“ unter Verbindungen › Integrationen (Hub ist Ort aller Integrationen: SPEC.md:174; Initial-Mark als Logo-Ersatz: ALFA Einstellungen.dc.html:303); die fünf Unterseiten sind fünf `list-section-header`-Blöcke in einer Karte. Das Master hat keine Tabs oder Unterseiten in einer Karte (ALFA Einstellungen.dc.html:97–134).
- offen: A oder B. Entscheidet Design mit dem Owner (PROJEKT-REGELN.md:7–8). Die folgenden Tabellen gelten für beide Varianten.
- offen: Überschneidung mit „Vorlagen“. SPEC.md:161 zählt Planunterlagen und Musterseiten (DWG, PDF, HTML) bereits zu den Vorlagen der Firma; im Bogen ist Vorlagen eine Namensliste mit „Anlegen“ und Entfernen per Hold (ALFA Einstellungen.dc.html:341; views.json:240–245).

### 2.4 Unterseiten: vorhandene Teile und Bedarf
**Profile** (Profil je Firma/Nutzergruppe)
- Teile: `settings.message-row` oder `settings.list-row` je Profil; `settings.field-row` mit Eingabe für Name (ALFA Einstellungen.dc.html:124); `choice` + `settings.anchored-menu` für „Aktives Profil“ (:127,:174); `confirm` für Entfernen (:129); `text-button` „Anlegen“ (:130); `settings.mark` mit Initial (:26,:303); Leerzeile als isNote (:102).
- Texte vorhanden: Name (texts.json:1541), Firma (:1765), Anlegen (:1445), Entfernen (:1453), Abbrechen (:1365).
- Texte neu (de+en, entscheidungen.md:436): „Profil“, „Nutzergruppe“, „Aktives Profil“, „Noch kein Profil.“ (Muster texts.json:2045), „Profil entfernen?“ (Muster ALFA Einstellungen.dc.html:341).
**Quellen** (Quellordner freigeben, widerrufen)
- Teile: Zeile „Projektordner“ mit `choice`-Pille „Wählen“ und Menü (ALFA Einstellungen.dc.html:321; SPEC.md:245); `connection-status` je Ordner (:119); `card-notice` failure mit `text-button` für verlorene Freigabe (:104,:305; texts.json:1373 „Erneut verbinden“); Widerruf per `confirm` (ALFA Einstellungen.dc.html:129,269); Block „Abgleich“ mit Takt-Pille und „Jetzt abgleichen“ für erneutes Einlesen (:316–320; texts.json:1989).
- Texte vorhanden: Projektordner (texts.json:1661), Zustand (:1525), Erneut versuchen (:1437).
- Texte neu: „Quellordner“, „Freigeben“, „Freigabe widerrufen?“, Zustandswörter für Freigabe (Dienstwörter SPEC.md:36 passen nicht wörtlich), Fehlertext „Ordner nicht erreichbar“ (Muster SPEC.md:245 „Ordner nicht geladen“).
**Vorlagen & CI** (Fonts, PDF, IDML, DWG/DXF, HTML/Mustache, SVG; Zweck je Datei)
- Teile: Gruppierung per `settings.list-section-header` je Dateityp (:101); je Datei eine `settings.field-row`: Dateiname links mit Auslassung in der Mitte (SPEC.md:108), Zweck als `choice`-Pille mit Menü und Häkchen (ALFA Einstellungen.dc.html:127,178), Importzustand als `connection-status`, Entfernen als `confirm` (:129); Anlegen als `text-button` (:130; Muster :341).
- Texte vorhanden: Vorlagen (texts.json:1677), Vorlage (:2053), Vorlage anlegen (:1797), Noch keine Vorlage. (:2045).
- Texte neu: Dateitypen, Zweckwerte (Plankopf, Maßzeichnung, Präsentation, Stückliste, Schrift), „Zweck“, „Datei hinzufügen“, Importfehler je Format.
**Seeds** (Beispielpläne)
- Teile: `settings.field-row` je Beispiel mit `sub` (Datum, Seitenzahl; ALFA Einstellungen.dc.html:116) und `connection-status` mit Zustand „working“ samt Fortschrittstext (:301,:66); `text-button` „Erneut lesen“; Entfernen per `confirm`.
- Texte vorhanden: Anlegen, Entfernen, Erneut versuchen (siehe oben).
- Texte neu: „Beispielpläne“, „Liest …“, „Gelesen“, „Noch kein Beispielplan.“
**Regelprüfung** (Claude schlägt vor, Nutzer bestätigt)
- Teile: zwei `settings.list-section-header` („Vorgeschlagen“, „Bestätigt“); je Regel eine `settings.field-row`: Schlüssel als Label, Wert und Einheit als Eingabe (:124), Beleg Datei und Seite als `sub` (:116), Entscheidung als `segmented-control` mit `option` (:128; schmal wird es Pille: :459); Sammelhinweis als `settings.card-notice` mit `text-button` (:104); `counter` ohne Ring für offene Vorschläge (components.json:1196–1200).
- Bestätigen ist nicht destruktiv: einfacher `text-button`; Hold-Pille ist im Master für Trennen, Konto löschen und Vorlage entfernen belegt (SPEC.md:75; views.json:229–245); Verwerfen eines bestätigten Eintrags per `confirm`.
- Texte neu: „Regelvorschläge“, „Beleg“, „Bestätigen“, „Ablehnen“, „Wert“, „Einheit“, „Noch keine Vorschläge.“

### 2.5 Lücken: Design-Master zeichnet neu (Bedarf, keine Gestaltung)
| Nr | Bedarf | Beleg des Fehlens |
|---|---|---|
| L1 | Einbettung von Creative Claude (Gruppe oder Kachel, Unterseiten) | ALFA Einstellungen.dc.html:231,402; SPEC.md:32 |
| L2 | Dateiorte-Karte und Vorlagen-Ansicht als Auftrag an Design, nicht gezeichnet; vier Dateiorte (Mac, Drive, Dropbox, WebDAV/SMB) | SPEC.md:160,163; HANDOFF.md:101 |
| L3 | Freigabe eines lokalen Ordners (grant, revoke, Freigabe verloren); gezeichnet ist nur der Drive-Projektordner in zwei Schritten | SPEC.md:245; ALFA Einstellungen.dc.html:321 |
| L4 | Dateityp-Symbole (Schrift, Plan, Vorlage) und Zweck-Zuordnung je Datei; der Bogen übergibt nur allgemeine Pfade (docD, folderD, attachD, lockD u. a.); symbols.json nicht gelesen | ALFA Einstellungen.dc.html:515 |
| L5 | Import- und Lesezustände je Datei und Beispiel (Liest, Fertig, Fehler); Zustandswörter gelten nur für Dienste | SPEC.md:36 |
| L6 | Prüfansicht für Regelvorschläge mit Beleg (Datei, Seite), Vorschaubild des Belegs; fremde Inhalte bleiben unbehandelt hell | SPEC.md:106; kein Master-Bauteil in components.json |
| L7 | Datei ablegen per Drag auf die Karte; `drop-overlay` existiert nur in Mail | components.json:3386–3411 |
| L8 | Schalter „Assistent darf nutzen“ je Hub-Integration | SPEC.md:174 |
| L9 | Logo oder Initial-Mark für Creative Claude | SPEC.md:44; ALFA Einstellungen.dc.html:303 |
| L10 | Texte: kein Creative-Claude-Schlüssel im Katalog; alle Texte sind set-by-design bis der Owner freigibt | texts.json:1290–2243; HANDOFF.md:138 |

### 2.6 Regeln des Masters für den Build-Agent
- Hülle nur einmal: Bahnen, Griffe, Blob, Radien, Abstände kommen aus der Hülle; jede Abweichung vollständig in allen Ansichten (PROJEKT-REGELN.md:3–5). Keine Aussage ohne Beleg (PROJEKT-REGELN.md:7–8).
- Tokens nur von Design; Code benennt unter der Oberfläche, Design übersetzt; keine losen Maße (SPEC.md:84; HANDOFF.md:122). Werte aus `contract/base.tokens.json`; Bogen nutzt z. B. `--spacing-step8`, `--radius-row`, `--size-hairline` (ALFA Einstellungen.dc.html:47,113).
- Eine Karte, ohne Kopf, bündig; Auswahl links zeigt die offene Karte (SPEC.md:33). Kachelhöhe 112, Radius 12, Kacheln nur unter Verbindungen (SPEC.md:72).
- Löschen und Trennen über Hold-Pille 1 s (SPEC.md:75). Toast: Rückgängig 4 s; Fehler mit Warnzeichen und „Erneut versuchen“ (SPEC.md:75,242; ALFA Einstellungen.dc.html:170).
- Keine Erklär- oder Metasätze unter Knöpfen und Zeilen; Fehler- und Warntexte sind erlaubt (SPEC.md:107). Rechte: Wer angemeldet ist, darf alles; keine Schutztexte (SPEC.md:151).
- Geist, keine Monoschrift, keine Zahlen in Ringen, keine ⌘-Kürzel, Farbe nie auf Aktionen, Signalrot nur für Destruktives (SPEC.md:106; der Bogen setzt Signal zusätzlich für Fehlerzustände: ALFA Einstellungen.dc.html:390,412), keine farbigen Kanten (SPEC.md:106; entscheidungen.md:232). Tooltips sind der System-Titel (SPEC.md:106).
- Fremde Inhalte (PDF, Bild, Plan) werden nie eingefärbt (SPEC.md:106).
- Alle Texte als Sprachpaket de+en im Katalog (entscheidungen.md:436; texts.json:2).
- Farbwelten, Farbleiter und Liquid Glass sind gesperrt oder Exploration, nicht bauen (SPEC.md:54; entscheidungen.md:445).
- Design-Reihenfolge: UI erst nach Master. Fehlt ein Bauteil, stoppt der Bau und der Bedarf geht als L-Eintrag an Design (SPEC.md:103; PROJEKT-REGELN.md:7–8).

## 3 Fachkern Creative

Belege: `H` = HANDOFF_Fusion_Kuechen-Session.md (Zeile), `R1` = regeln_runde1.md (Zeile), `V0` = entwurf_v0.md, `SB` = SVG-Planbibliothek/README.md (Zeile), `MD` = Musterdaten/LIESMICH.txt (Zeile). Status: [B] bemaßt, [A] abgeleitet, [N] Annahme (`R1:3`).

### 3.1 Kern und Profil

Leitwort: Der Kern kennt Verfahren, das Profil kennt Werte.
Test: Ändert sich ein Wert zwischen zwei Firmen, gehört er ins Profil.

| Kern (firmenneutral) | Profil (je Firma/Nutzergruppe) |
|---|---|
| Bausteinfunktionen mit Parametern statt Maßen | Maße, Plattenstärken, Fugen, Raster |
| Hierarchie KUECHE>ZEILE>SCHRANK>Teile | Namensmuster, Materialien, Lieferanten, Fusion-Darstellungsnamen |
| Prüfroutine (Verfahren) | Schwellen der Prüfroutine (Mindestmaße) |
| Ableitungsformeln, Konfliktregeln | Plankopf-Felder, Blattliste, Maßstab, optionaler Stempel (ob, Text und Farbe je Nutzer-Setup) |
| Ingest, Learn, Render (als Rollen; ALFA-Ordner siehe §1.1-Tabelle) | Vorlagen, Fonts, CI, Beispielpläne |

Regel: Kein Firmenname in Code, Tests, Prompts und Kern-Dokumenten. Tests laufen gegen ein Fantasieprofil `test-neutral`. (Vorschlag)

Runde-1-Werte einsortiert (`R1`):

| Wert | Ort | Schlüssel / Logik |
|---|---|---|
| Sockel 100, Fronthöhe 790, AP 35, Raster 600, Fuge Stellseite-Front 5 (`R1:6-10`) | Profil [B] | `sockel_h`, `front_h`, `ap_d`, `raster_b`, `fuge_stellseite_front` |
| Stellseite 32,5; Deckplatte 30; Front 26 hinter Vorderkante (`R1:11-13`) | Profil [A] | `stellseite_d`, `deckplatte_d`, `front_setback` (Formel am Wert) |
| Korpus 19, Rückwand 8, Front 19, Fuge 3 (`R1:15`) | Profil [N] | `korpus_d`, `rueckwand_d`, `front_d`, `fuge_front` |
| Zargenhöhen 235/115/115 (`R1:16`) | Profil [B] | `zarge_h[]` |
| Griffmulde 15 (`R1:14`) | Profil [B], Baustein offen | `griff_ueberstand` |
| OK AP 925 = 100 + 825 (`R1:7`) | Kern-Formel | `ok_ap = sockel_h + front_h + ap_d` (790+35=825; Vorschlag) |
| Spülenschrank ohne vordere Traverse (`R1:19`) | Kern-Konfliktregel | Baustein-Option `traverse_vorn=false`, wenn Geräteplatzhalter vom Typ `spuele` kollidiert |
| GSP vollintegriert, nur Front (`R1:20`) | Kern-Gerätemodus | `geraet(modus="front_only")`; Einsatz je Küche im Job |
| Steckdosen 2× je Stellseite, Produktname (`R1:21`) | Profil [B] | `steckdose_je_stellseite`, `steckdose_typ` |
| Nischenmöbel 2200, Nische 1235 (`R1:12`) | Job-Parameter | Projektwert, weder Kern noch Profil |
| Materialien, Lieferanten, Dekor (`R1:23-25`) | Profil | `material.*` mit Fusion-Darstellungsname |
| A3 quer, 1:10, mm, Höhen auf OKFF, Blattliste, rechte Spalte (`R1:27-31`); Stempel optional: ob, Text und Farbe setzt der Nutzer im Setup, Standard aus, kein Stilmerkmal | Profil [B] | `stil.*`; Mechanik (Felder befüllen) im Kern |

### 3.2 Datenmodell (GRDB)

| Entität | Felder |
|---|---|
| `profile` | id, name, kind (`firma`/`gruppe`), parent_id (optional, Vererbung; Vorschlag), version, created_at |
| `source` | id, profile_id, bookmark (security-scoped), path_hint, state (`freigegeben`/`widerrufen`), granted_at |
| `asset` | id, source_id, relpath, format, purpose, sha256, ingest_state (`neu`/`gelesen`/`fehler`/`veraltet`), read_report (JSON: Seiten gelesen/gesamt, Modus `vektor`/`raster`/`gemischt`), license_note |
| `purpose` | Enum im Kern (3.3), keine Tabelle |
| `rule` | id, profile_id, key, value, unit, status (`bemasst`/`abgeleitet`/`annahme`), evidence_asset_id, evidence_ref (Seite/Layer/Feld), derivation (Pflicht bei `abgeleitet`), proposed_by (`learn`/`nutzer`), confirmed_at (null = Vorschlag), supersedes_id |
| `job` | id, profile_id, project_ref, step (Pipeline 3.4), params (JSON), state, result_ref (Fusion-Dokument, Prüfbericht, Render-Dateien), started_at, ended_at |

Invarianten (Check-Constraints im Store):
- Build liest ausschließlich `rule` mit `confirmed_at != null`.
- „1:1“ im Bericht nur bei `bemasst` (`H:25`).
- `annahme` erscheint im Bericht mit Kennzeichen (`H:24`).
- Ingest liest nur Assets unter `source.state = freigegeben` (`H:24`).

`profil.json` (Export/Import des Profils; JSON wegen §1.5, Entscheidung E6; Beispielwerte aus Runde 1, Firmenwerte nur hier):

```json
{
  "profil": "beispiel-studio", "version": 1, "kind": "firma",
  "regeln": [
    {"key": "sockel_h", "wert": 100, "einheit": "mm", "status": "bemasst", "beleg": {"asset": "plan-runde1", "ref": "S.2, S.4"}},
    {"key": "front_h", "wert": 790, "einheit": "mm", "status": "bemasst", "beleg": {"asset": "plan-runde1", "ref": "S.2, S.4"}},
    {"key": "ap_d", "wert": 35, "einheit": "mm", "status": "bemasst", "beleg": {"asset": "plan-runde1", "ref": "S.2, S.4"}},
    {"key": "stellseite_d", "wert": 32.5, "einheit": "mm", "status": "abgeleitet", "ableitung": "(1875-1810)/2", "beleg": {"asset": "plan-runde1", "ref": "S.2"}},
    {"key": "korpus_d", "wert": 19, "einheit": "mm", "status": "annahme", "bestaetigt": null}
  ],
  "material": {
    "front": {"lieferant": "lieferant-a", "produkt": "Edelstahl gebürstet", "darstellung": "Edelstahl - satiniert"},
    "korpus": {"lieferant": "lieferant-b", "produkt": "Melaminharz", "dekor": "tbd"}
  },
  "stil": {"papier": "A3-quer", "massstab": "1:10", "einheit": "mm", "hoehen_auf": "OKFF", "stempel": {"aktiv": false, "text": null, "farbe": null}},
  "blaetter": ["perspektive", "frontal", "frontal_innen", "rechts"],
  "quellen": [
    {"id": "plan-runde1", "datei": "plan_runde1.pdf", "zweck": "masszeichnung_vorbild"},
    {"id": "blatt-a3", "datei": "vorlagen/a3_plan.svg", "zweck": "blattvorlage"}
  ]
}
```

### 3.3 Zweck-Katalog (`purpose`)

Regel: Eine Datei wird nur für ihren Zweck verarbeitet. Passt das Format nicht, lehnt Ingest mit Grund ab.

| purpose | erlaubte Formate | gelesen wird |
|---|---|---|
| `masszeichnung_vorbild` | PDF (Vektor), SVG, DXF, DWG (nach Konverter) | Maßketten, Maße, Materialliste, Layer, Linienstärken, Schraffur |
| `stil_referenz_visuell` | PDF (Raster), PNG, JPG | Layout und Anmutung für das Review; keine Maße (`MD:6`) |
| `blattvorlage` | SVG, HTML, Mustache, IDML | Papierformat, `data-field`-Namen, `#drawing-placement`, Gruppen Rahmen/Plankopf/Seitenleiste/Status (`SB:17`) |
| `praesentation_vorlage` | IDML, PDF, HTML, Mustache | Seitentypen A4 quer, Felder, Bildplätze (`SB:7`) |
| `ci_schrift` | OTF, TTF, WOFF2 | Familie, Schnitte, Lizenzflag; prozesslokal registriert |
| `ci_marke` | SVG, PDF, PNG | Logo, Farbwerte (Hex) |
| `konstruktion_3d` | IFC (bevorzugt), STEP, X_T | Bauteilstruktur, Maße (`H:120`); `.vwx` ist nicht lesbar |
| `liste_stueck_zuschnitt` | CSV, XLSX | Stück-, Zuschnitt-, Beschlagspalten und Reihenfolge (`H:120`) |
| `daten_muster` | JSON | Blattdaten-Beispiele (`SB:11`, `data/pages.json`) |

### 3.4 Pipeline

| Schritt | Inhalt | Fertig, wenn |
|---|---|---|
| 1 Setup | Profil anlegen, Quellordner freigeben (Bookmark), Datei je Asset einem Zweck zuordnen | jedes Asset hat `purpose` mit passendem Format; `source.state = freigegeben` |
| 2 Ingest | Je Format ein Importer: PDF-Text/Vektor, SVG/HTML/Mustache (`data-field` listen), IDML (XML), DXF (Layer/Entitäten), IFC/STEP, Fonts (registrieren), CSV/XLSX | `read_report` meldet Seiten gelesen = Seiten gesamt und Modus je Seite; Hash gespeichert |
| 3 Learn | Claude liest Assets vollständig und schlägt Regeln vor: Schlüssel, Wert, Status, Quelle+Seite | jeder Vorschlag trägt `evidence_ref`; `abgeleitet` trägt `derivation`; Rohwerte nach Schlüssel gebündelt |
| 4 Review | Nutzer bestätigt, ändert oder verwirft je Regel; Beleg-Ausschnitt sichtbar | Vorschläge: 0 offen; bestätigte Regeln haben `confirmed_at` |
| 5 Build | Job-Parameter + bestätigte Regeln → Skripte je Baustein → Fusion (3.5) | Fusion-Dokument enthält KUECHE-Hierarchie; jeder Baustein-Aufruf lief in ≤60 s (`H:37`); Dokument bleibt ungespeichert bis Nutzer-OK (`H:27`) |
| 6 Check | Prüfroutine aus `H:109-116` plus Profilschwellen | Bericht je Prüfpunkt grün oder begründet; jede Zahl trägt gemessen/Quelle/Annahme |
| 7 Render | Blattvorlage + Zeichnung + Blattdaten (`SB:17`) → SVG/PDF | alle `data-field` befüllt; Papier 420×297; Maßstab-Kette stimmt (unten); Status-Gruppe gesetzt |

Prüfroutine Check (aus `H:111-116`), Reihenfolge fest:
1. Timeline `healthState`.
2. Körperanzahl und Bounding-Boxen in Weltkoordinaten.
3. Kollisionen mit Ausnahmeliste; bbox-Vorfilter, Schwelle 0,05 mm³ (`H:84,104`).
4. Mindestmaße und Abstände gegen Profilschwellen (`H:105`).
5. Screenshots iso und front.
6. Bericht mit gemessen/Quelle/Annahme.
Zusatz (Vorschlag): Soll-Ist-Vergleich Ist-Maße gegen `rule`-Werte; `ok_ap` gegen Formel.

Render-Regeln:
- Ansichten: Frontal, Frontal Innen, Rechts, Perspektive je Profil-Blattliste (`R1:29`); Drei-Seiten-Ansicht als Standardsatz (`H:28`).
- Maßstab (Vorschlag): 1 SVG-Einheit = 1 pt (`SB:34`); 1:10 ergibt 1 mm Modell = 72/25,4/10 ≈ 0,2835 pt.
- Maßzahlen aus Regeln und Bounding-Boxen setzen, nie aus Pixeln; die Bibliothek verknüpft Maße nicht mit Geometrie (`SB:36`).
- Der Blatt-Rahmen kommt aus dem Profil; die Bibliothek rekonstruiert keine CAD-Objekte (`SB:30`), Ansichten entstehen aus dem Fusion-Modell.

### 3.5 Fusion-Brücke

Kopplung: Kern erzeugt Python-Skripte mit Profilwerten als `userParameters`; Ausführung über `fusion_mcp_execute` (`featureType: "script"`, `def run(_context)`, `H:34-35`).

Struktur (`H:46`): `KUECHE > ZEILE_x > SCHRANK_x > Teile`, Komponente je Bauteil, Namen = Funktion + Maß. Dokumenttyp „Fusion-Design“ (Bauteilkonstruktion erlaubt nur eine Komponente, `H:45`).

Bausteinbibliothek `kueche_lib.py` (`H:122`, Funktionen des Kerns, Parameter aus Profil/Job):

| Funktion | Parameter (Schlüssel) |
|---|---|
| `unterschrank` | breite, korpus_d, rueckwand_d, sockel_h, front_h, fuge_front, traverse_vorn, schubkaesten[] |
| `hochschrank`, `oberschrank` | breite, hoehe, tiefe, korpus_d, rueckwand_d, boeden |
| `arbeitsplatte` | laenge, tiefe, ap_d, ausschnitte[] (Spüle, Kochfeld) |
| `stellseite` | h, tiefe, stellseite_d, seite |
| `geraet` | typ, b, t, h, modus (`platzhalter`/`front_only`) |
| `sockel`, `blende`, `front` | laenge, sockel_h, front_d, fuge_front |
| `schubkasten` | zarge_h[], breite |
| `stueckliste` | Komponentenbaum → Zeilen (Instanzen zählen mit, `H:47`) |

Gemeinsame Helfer: `P3`, `V3`, `VI`, `param()` (`H:52-55,59`).

Stolperfallen als Regeln:
- Parameteranlage und Geometrie laufen im selben Skript, sonst geht der Parameter beim Rollback verloren (`H:38`).
- Nach Timeout zuerst `readOnly: true` prüfen (Timeline-Länge, Skizzenname), dann entscheiden (`H:37`).
- `readOnly: true` verändert nichts, auch keine Opacity oder Kamera (`H:36`).
- Mehrfach genutzte Teile als `addExistingComponent`; danach `isGroundToParent = False`, positionieren, `snapshots.add()` (`H:47,99-101`).
- Position nach jedem Setzen per Bounding-Box in Weltkoordinaten prüfen (`H:103`).
- CUT: `participantBodies` begrenzen, Distanz explizit, danach Körperanzahl und Kollision prüfen (`H:64-65,97-98`).
- XZ-Skizzen: Koordinaten über `modelToSketchSpace` (`H:70`).
- Darstellung vor Nutzung per Namenssuche in der Bibliothek prüfen (`H:41`).
- Wurzelkomponente behält ihren festen Namen; `KUECHE` ist die erste Unterkomponente. (Beleg: Fusion-Fehler „3 : root component name cannot be changed“ in Runde 1, 30.10.)
- Spülenschrank ohne vordere Traverse (`R1:19`), GSP nur als Front (`R1:20`).
- Wichtige Lagen bemaßen; berechnete Positionen passen sich nicht an, dann Baustein neu ausführen (`H:106`).
- Türen und Auszüge später als Joints (`H:107`).

### 3.6 Offene Punkte

1. DWG-Konverter: Auswahl, Lizenz, Prozessgrenze in der Sandbox offen (`V0:20`); DXF und SVG laufen ohne Konverter.
2. Raster vs. Vektor: Musterpläne sind Bildseiten (`MD:6`); die Bibliothek enthält teils `raster-source` (`SB:25`); Beschriftungen im Vektor sind überwiegend Pfadkonturen (`SB:23`). Folge: Maße brauchen OCR oder Text-Layer. Vorschlag: Status `bemasst` nur bei Text-Layer oder Review-Bestätigung am Beleg-Ausschnitt, sonst `annahme`.
3. Font-Lizenz: Einbettung in SVG/PDF und Weitergabe offen (`V0:20`). Vorschlag: `license_note` je Asset, Einbetten nur bei Flag `einbettbar`.
4. Parametrik der BaseFeature-Körper: `TemporaryBRepManager` → `baseFeatures` ist schnell (`H:77-82`), folgt aber keinen Parametern. Vorschlag: Korpus, Fronten, Platten per Extrusion mit `userParameters`; Geräteplatzhalter per BaseFeature; Wertänderung = Baustein neu ausführen.
5. Ansichten aus Fusion: Ableitung der Drei-Seiten-Ansichten als Vektor (Kantenprojektion vs. Fusion-Zeichnung) ist ungeprüft.
6. Griffmulde (Überstand 15, `R1:14`): Baustein fehlt.

## 4 Entscheidungen für den Owner

Belegkürzel wie §1 (C, R, Y) und §2.

| Nr | Frage | Optionen | Beleg |
|---|---|---|---|
| E1 | Modulname und -ort | `Creative` in `Sources/Integrations/Creative` · anderer Name (Kollision mit Editoren-Modul „creative suite“) | §1.6; C:29 |
| E2 | Aufnahme in ALFA | Creative in CLAUDE.md Decisions/Next tasks, `utils/check.py`, Modultabelle, `project.yml` – nur auf Wort des Owners | §1.5; C:41 |
| E3 | Platz in Einstellungen | A: eigene Gruppe mit 5 Einträgen · B: Kachel unter Integrationen, 5 Blöcke in einer Karte | §2.3 |
| E4 | Verhältnis zu „Vorlagen“ der Firma | Creative nutzt die Firmen-Vorlagen mit · eigene Vorlagenliste | §2.3; SPEC.md:161 |
| E5 | Begriff „Seeds“ | „Beispielpläne“ (Vorschlag) · anderer Begriff; „Seed“ ist in Calculation belegt | §1.5; C:55 |
| E6 | Profilformat | JSON nach Muster `company.example.json` (Vorschlag) · YAML mit neuer Abhängigkeit | §1.5; R:5 |
| E7 | Fusion-Kopplung | ausgehender localhost-Client · Übergabeordner · MCP wie in dieser Session | §1.6; Y:91 |
| E8 | Datenschutzkategorie für Quelldateien an Claude | `studioKnowledge` · neue Kategorie | §1.6; R:134 |
| E9 | Design-Aufträge L1–L10 an DESIGNCHANNEL | nach Bestätigung durch den Owner | §2.5; C:40 |
| E10 | DWG und Font-Lizenzen | Konverter (z. B. ODA) · nur DXF; Einbetten nur mit Flag | §3.6 |

## 5 Wissenspaket Küche

Eigene Datei `wissenspaket/KAPITEL_WISSENSPAKET.md` (Stand 31.10.2026, Version 0.2, Entwurf) mit Beilagen `wissenspaket/schema/` (JSON Schema v0.2, Beispiele, Negativbeispiele), `wissenspaket/pruefe_schema.py` und `wissenspaket/recherche/` (fünf Recherchen mit Quellen, Prüfberichte). Entscheidungen E11–E18 und offene Fragen F1–F14 stehen dort in §5.13. Wo §1–§4 „Profil“ sagen, heißt es in §5 „Setup“.
