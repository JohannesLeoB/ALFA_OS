# Architecture

## Modules

`Package.swift` declares fifteen library modules and one test target per module. The app target in `project.yml` links all of them. GRDB 6.29.3 is the only external dependency.

| Module | Depends on |
|---|---|
| Core | none |
| Design | none |
| Shell | Design |
| Storage | Core, GRDB |
| Hub | Core, Design, Storage, GRDB |
| Mail | Core, Design, Shell, Storage, Hub, GRDB |
| Calculation | Core, Storage, GRDB |
| Assistant | Core, Design, Storage, Hub, Calculation, GRDB |
| Google | Core, Hub, Mail, Assistant |
| Microsoft | Core, Hub, Mail, Assistant |
| Airtable | Core, Hub, Assistant, Calculation |
| ClickUp | Hub, Assistant |
| Sevdesk | Hub, Assistant, Storage, GRDB |
| Clockodo | Core, Hub, Assistant, Storage, GRDB |
| Shipping | Core, Hub, Assistant |

The table is the complete edge list. Integrations never depend on each other; they meet in the app. `App` holds the SwiftUI views and the composition root (`Assembly`, `AppSession`, `ToolShelf`) and depends on every module.

## Schema

`utils/check.py` enforces the rules marked (check) and only those; every other rule is reviewed. Rules marked (check) are enforced only as far as the text says.

### Layout

```
App/<Feature>/           SwiftUI views, one folder per area, Swift files directly inside
Sources/<Module>/        modules without UI
Sources/Integrations/<Service>/   Airtable, ClickUp, Sevdesk, Clockodo, Shipping, Google, Microsoft
Tests/<Module>Tests/<Module>Tests.swift   one test class per module
Resources/               tokens, text sources, catalog, fonts, assets, plist
utils/                   checks, generators, build script
DESIGN/                  latest and previous design master (ZIP) and MANIFEST.json (check)
```

- Module names (check): Core, Design, Shell, Storage, Hub, Assistant, Mail, Calculation, Catalog, Project, Today, Survey, and the integrations above. Catalog, Project, Today and Survey are reserved for later; no code exists for them.
- A module holds only the subfolders below, no files directly (check). Each subfolder holds Swift files directly (check).
- A Swift file in `App` or `Sources` has at most 800 lines (check); 200 to 600 is the aim. Related types of one function live together in one file of their folder instead of one file per type (Johannes 30.10., reviewed).

| Folder | Content | Rule |
|---|---|---|
| `Model/` | value types (struct, enum) | no I/O, no state |
| `Logic/` | pure functions and engines | deterministic, testable without mocks |
| `Port/` | protocols to the outside world | the ports of one function in one file, named after the main port (reviewed) |
| `Adapter/` | implementations of a port: HTTP, IMAP, Keychain, files | the place for I/O |
| `State/` | `@Observable` state for views | I/O only through ports |
| `Store/` | persistence, implements a port | the place for database and file access |
| `Tool/` | assistant tools, Assistant only (check) | the tools of one function in one file, named after the main tool (reviewed) |

### Names

- The file name is the main type it declares (check); the file also holds that type's related types, extensions and `private` helpers (reviewed). A file `Type+Aspect.swift` contains a top-level extension of `Type` (check) and is used only where the main file would pass 800 lines.
- ASCII outside strings and CamelCase file and type names (check). Identifiers are English and carry no module prefix; a domain prefix only where a name collides with Swift or SDK names (reviewed).
- Forbidden name words: Manager, Helper, Helpers, Util, Utils, Utility, Utilities, Service, Services, Handler, Impl, Base, Common, Misc, New, Old, version numbers such as V2, and trailing digits (check for file names and for struct, class, enum, protocol, actor and typealias names; properties, functions and cases are reviewed). `Base64` is the one allowed digit name.
- Role suffixes:

| Suffix | Meaning | Folder |
|---|---|---|
| none | domain model | Model |
| `Client` | talks to an external API | Adapter |
| `Store` | reads and writes persistently | Store |
| `Engine` | pure computation over models | Logic |
| `Router` | picks an implementation or target | Logic or Adapter |
| `Parser` | text or data to model | Logic or Adapter |
| `Registry` | catalogue of tools or providers | Tool or Logic |
| `Tool` | assistant tool | Tool |
| `Port` | protocol | Port |
| `Failure` | error enum of a module | Model |
| `State` | UI state | State (or Model) |

- Folder placement of Client, Engine, Failure, Parser, Port, Store, Tool and State names is checked; the folders Port, Tool (also Registry), Store and State accept only their own suffix; `Type+Aspect.swift` files are exempt (check).
- View names in `App` are named after the thing, Apple style: `MessageRow`, `DraftEditor`, `InboxLane`, `SettingsCard`. The `View` suffix is used only where a model has the same name. `ButtonStyle`, `ToggleStyle` and `Layout` conformances end in the protocol name. `View+Aspect.swift` holds a private `ViewModifier` and a `View` method.
- View suffixes (Row, List, Detail, Card, Lane, Button, Editor, ButtonStyle, ToggleStyle, Layout) are not used in `Sources`; the suffixes Client, Store, Engine, Router, Parser, Registry, Tool, Port and Failure are not used in `App` (check).
- `Tests` holds one folder `<Module>Tests` per module with exactly the file `<Module>Tests.swift` (check).

### Content

- No comments of any kind (check).
- No prose in code: user-facing text exists only as keys in `Resources/Localizable.xcstrings` (reviewed; a literal sentence in a view is not detected). `utils/merge_strings.py --check` reports a key used through the call patterns listed under Texts that has no value, when its first segment is already a catalog prefix (check, partial).
- No literal colours or numbers in `App` views except 0, 1 and 2; sizes, spacing, radii, durations and every other value come from `Design` tokens or `App/Design/SheetValues.swift` (check for numeric literals and numeric colour initialisers; `Color.white`, `.black` and named system colours are reviewed).
- The company name never appears in Swift files of `Sources`, `App`, `Tests` or in `.py`, `.sh` and `.plist` files of `utils` (check); `Resources`, `project.yml`, `.githooks` and `.github` are not scanned. Company values reach the app only through the company configuration file (see [README.md](README.md)).
- Markdown: exactly `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md`; every link, repository path and file name in them exists (check); identifiers and behaviour claims are not checked.
- Generated files match their generators (check).
- Access: `internal` by default, `public` only across module boundaries. Every `public` member has a caller outside its module. No stubs, no provisional code. These three rules, the Layering rules and the rules for `Model`, `Logic`, `Port`, `State` and `Store` above are reviewed, not checked.

## Layering

Dependencies point from the outer layers to the inner ones inside a module (reviewed):

```
State, Tool -> Port, Logic, Model
Store, Adapter -> Port (implements), Model
Logic -> Model
```

- `Model` and `Logic` perform no I/O and hold no state.
- `Port` protocols are the only way `State`, `Logic` and `Tool` reach the outside world.
- `Adapter` and `Store` implement ports and are the only code that touches network, Keychain, files or the database.
- A port is declared in the module that consumes it where the implementing module depends on the consumer. Example: `MailSearchPort` is declared in Assistant and implemented by `MailSearchClient` in Google.

## Composition root

`App/Shell/Assembly.swift` builds every dependency once: it opens the database, runs the legacy import, creates the stores, the provider list (`ProviderPort`), `Connections`, `InboxState`, `ChatStore`, `ToolShelf`, `ConversationEngine` and `ChatState`. `App/Shell/AppSession.swift` owns the `Assembly` and the desk state, creates the panes (`mail`, `settings`) and starts mail sync. `App/Shell/AlfaApp.swift` creates the session with `AppSession.live()`. Besides `Assembly`, `ToolShelf` constructs the integration clients and the stores its tools need, and `AppSession` constructs `ShellStore`. `ToolShelf` creates the assistant tools for the integrations whose inlet is connected; `Assembly.reshelve()` rebuilds the registry when inlets change.

## Data

- One SQLite file `alfa.sqlite` in the Application Support folder `ALFA_OS`, opened by `DatabaseStore` with write-ahead logging and foreign keys on.
- Migrations are registered in `SQLiteStore+Migrations.swift` and `SQLiteStore+CalculationMigration.swift` under the names hub, mail, audit, assistant, project, catalog, clockodo, sevdesk, calculation and mailMirror, and run when the database opens.
- Every database-backed store takes the `SQLiteStore` through its initializer (`ClientConfigStore`, `ShellStore`, `KeychainStore` and `AttachmentStore` use none). Secrets (API keys, passwords) are stored through `KeychainStore`, not in the database.
- `LegacyImportStore` runs at every start but imports once: it reads a legacy `hub.sqlite` next to the database and selected `UserDefaults` values, and then sets the setting `import.legacy.done`. `ReceiptStore.adopt(legacy:)` moves the old receipts out of `UserDefaults`.
- `MailboxStore` mirrors each mail folder into `mail_message` by id sets: `MirrorPort` (a protocol separate from `MailTransportPort`, implemented by `IMAPSMTPClient` and `GmailMailClient`, forwarded by `MeteredMail`) lists ids, fetches summaries and refreshes flags; a transport without it offers no range, and a refresh of it fails with `capabilityMissing`. One pass per inlet and folder runs at a time, `mail_cursor` keeps the Gmail history id and the reach of an extended folder, mail is ordered by `receivedAt` (Gmail: its `internalDate`), then `id`; the refused-wipe marker and the "older" offer persist in `mail_cursor`.
- Attachments of chat messages are files in the folder `attachments` next to the database.

## Design tokens

`Resources/tokens.json` is the single source for colours, sizes, spacing, radii, motion, typography, layers, shadows and surfaces. `utils/generate_tokens.py` reads it and writes `Tokens.swift` (including `Layer`, `Tracking`, `Scale`, `Ratio`, `TextStyle` and `Transition`), `Colors.swift`, `Moods.swift`, `Shadows.swift`, `Surface.swift` and `InkSet.swift` into `Sources/Design/Model`. `python3 -I utils/generate_tokens.py --check` fails when a generated file differs; `utils/check.py` runs it. Views read tokens through `Tokens`, `Colors`, `Moods`, `Shadows`, `Surface` and `InkSet`; `App/Design/Appearance.swift` selects light or dark values.

## Texts

Each module that has user-facing text owns `Resources/<name>.localizable.json`: keys with a `de` value and, where translated, an `en` value. `utils/merge_strings.py` merges these files into `Resources/Localizable.xcstrings` (source language `de`), keeps the catalog entries whose key is in a module file or matches a string literal in `App`, `Sources` or `Resources/*.json`, prunes the others, lets module values overwrite catalog values (printing `changed`) and adds missing `en` values. `--check` fails when the catalog is stale; it also lists keys used in code (`string(`, `text(`, `format(`, `key(`, `LocalizedStringKey(`, `LocalizationValue(`, and `...Key:` arguments) that have no value. Views resolve text through `Appearance`; engines resolve text through `TextPort`, implemented by `TextStore` in `App/Shell/Assembly.swift`.

## Assistant

- `ClaudeClient` talks to the Anthropic API with the key that `ClaudeCredential` (Hub) reads from the Keychain slot of the connected `claude` inlet.
- `ConversationEngine` runs a turn: it checks the privacy choices, prepares the conversation (`Grounding`, `MemoryEngine`), selects tools, calls the model, executes tool calls through `ToolRegistry.run` and stores everything in `ChatStore`.
- Tools implement `ToolPort` (`Sources/Assistant/Port/ToolPort.swift`): a name, an access level (`read`, `propose`, `write`), a privacy category, parameters and `run`.
- Privacy categories (`PrivacyCategory`): mail, calendar, contacts, drive, clickUp, notes, tasks, catalogCalculation, studioKnowledge, chat, time. The user disables categories in settings (`PrivacyStore`); `ToolAccessEngine.allowed` (declared in `ConversationEngine.swift`) removes the tools of a disabled category from the turn. `PrivacyChoices` in Hub adds `assistantOff`, `chatFiles` and `loadImages`.
- Model routing (`ModelRouter`): a request that mentions estimation words uses Opus; otherwise a turn with tools enabled uses Sonnet; otherwise a long or analytical request uses Sonnet; everything else uses Haiku. The model ids are constants in `ModelRouter`; the credential's own model setting defaults to `ClaudeKey.defaultModel`.
- Calculation runs through `CalculationTool`, which wraps `EstimationEngine` from the Calculation module with price anchors (seed, Airtable, learned and PDF-learned).

## Not wired

- The assistant chat (`App/Shell/AssistantPanel.swift`, driven by `ChatState`) opens in the blob. Drafts, estimates and calendar links show as one generic card, files as chips; the design has no own form for them yet. The scope row has no project source and always shows the home scope.
- These tools exist and are tested but `ToolShelf` does not register them: `FindOffersTool`, `ListProjectsTool`, `ListSamplesTool`, `LookupCustomerTool`, `ProposeContactTool`, `ProposeFileTool`, `ReadFileTool`, `SearchContactsTool`, `StudioKnowledgeTool`.
- The modules Catalog, Project, Today and Survey do not exist yet.
- `apps.json` lists two apps, Mail and Settings; panes exist for exactly those.

## Bow register

Which Swift file draws each element of the valid design master (Mail and Settings, compared on 30.10.2026). "Bow" names the line in the master's `*.dc.html` or `alfa-bausteine.js`; "not built" marks an element the code has no counterpart for yet. `utils/check.py` checks that every listed file exists; `utils/token_register.py` lists where each token is read. Whoever moves or merges a listed file updates its row in the same commit.

| Area | Bow element | Bow | Built in |
|---|---|---|---|
| Mail | switch-glass über Kopf und Liste (nicht über Deck) | Mail 14, Mail 925 | `App/Mail/FolderLane.swift`, `App/Mail/View+SwitchGlass.swift` |
| Mail | lane-header 44, gap 8, Polster 0 8 0 16 | Mail 16 | `App/Mail/FolderLane.swift`, `App/Components/LaneHead.swift` |
| Mail | scroll-line (Haarlinie line beim Scrollen) | Mail 16 | `App/Components/LaneHead.swift` |
| Mail | account-title: Name medium, Tooltip Adresse, Rechtsklick „Angezeigt als“ (Name/l | Mail 17, Mail 688-691 | `App/Mail/AccountTitle.swift`, `App/Mail/MailboxMenu.swift` |
| Mail | Faltknopf „Postfach falten“ (nur wenn ›1 Bahn offen) | Mail 18, Mail 705 | `App/Mail/FolderLane.swift` |
| Mail | lane-content Polster 8 | Mail 20 | `App/Mail/FolderLane.swift` |
| Mail | list-row Ordner: 36 hoch, gap 20, Polster 0 8, Radius row, gewählt Fläche --c-in | Mail 24-26, Mail 683 | `App/Components/LaneRow.swift` |
| Mail | counter Ordner (min 20, Polster 0 4, klein, tabellarisch; gewählt on-inv-2; Post | Mail 27, Mail 683 | `App/Mail/FolderLane.swift`, `App/Components/Counter.swift` |
| Mail | list-section-header „Labels“ (32, unten bündig, Polster 0 8 8, klein ink-3) | Mail 22, Mail 684 | `App/Mail/FolderLane.swift` |
| Mail | Label-Zeilen (tag-Symbol, ohne Zähler) | Mail 685 | `App/Mail/FolderLane.swift` |
| Mail | Postausgang als Ordnerzeile, Zähler rot bei Fehler | Mail 447, Mail 683 | `App/Mail/FolderLane.swift`, `Sources/Mail/State/InboxState+Presentation.swift` |
| Mail | account-deck: Höhe Kopf + 44·n, Höhe animiert deckOpen/deckClose | Mail 32, Mail 694-697 | `App/Mail/AccountDeck.swift`, `App/Mail/Deck.swift` |
| Mail | account-card (Fläche LEVELS grau Stufe k, Tinte, Radius nur unten, Lack mit Fuge | Mail 33, Mail 699, Mail 624-633, B:3 | `App/Mail/AccountCard.swift`, `App/Mail/AccountDeck.swift`, `App/Components/View+Lacquer.swift` |
| Mail | card-header der Konto-Karte (44, Polster 0 48 0 6, Marke 28 mr 12 Ring 22 %, Nam | Mail 33 | `App/Mail/MailboxRow.swift`, `App/Mail/DeckRow.swift`, `App/Mail/Deck.swift` |
| Mail | account-alert Punkt 8, signal, −1/−1 | Mail 33, Mail 36 | `App/Mail/AccountAlert.swift` |
| Mail | Konto-Karte Hover hebt 4 px (nicht die letzte), 320 ms Feder | Mail 33 (style-hover), Mail 699 | `App/Mail/AccountCard.swift` |
| Mail | Wechsel-Geist (Karte steigt, Fläche → lane, Ring → Schatten, blendet aus) | Mail 34, Mail 700-704 | `App/Mail/MailboxGhost.swift`, `App/Mail/AccountDeck.swift` |
| Mail | lane-footer im Modus „Kopf“: „Neue Mail“-Kopf 44, Fläche lane, Radius unten nur  | Mail 35, Mail 694-698 | `App/Mail/AccountDeck.swift`, `App/Mail/ComposeHead.swift` |
| Mail | Marke „Neue Mail“ (28, Ring 22 %, Hover Fläche hover + Ring ink-3), Druck .98 | Mail 35 | `App/Mail/ComposeHead.swift` |
| Mail | Absendername rechts daneben (klein, Deckkraft cardMeta, rechts 48 frei) | Mail 35, Mail 692 | `App/Mail/ComposeHead.swift` |
| Mail | Deck-Schalter (28, rechts 8 oben 8, ink-3, Ring line-strong; Hover ink + Ring in | Mail 36, Mail 697 | `App/Mail/AccountDeck.swift`, `App/Mail/EnvelopeButton.swift` |
| Mail | envelope-stack (3 Umschläge 14×10 r2, Klappe, Versatz, Federzeiten) | Mail 36, Mail 695-696 | `App/Mail/EnvelopeStack.swift` |
| Mail | Tooltip Deck-Schalter | Mail 697 („Postfächer zeigen · neue  | `App/Mail/AccountDeck.swift` |
| Mail | Alarmpunkt am Deck-Schalter (zu, andere ungelesen) | Mail 36, Mail 697 | `App/Mail/AccountDeck.swift` |
| Mail | Streifen gefaltete linke Bahn: Ordner + „Neue Mail“ (Akzent); Postausgang mit Pu | Mail 653-655 | `Sources/Mail/State/InboxState+Strip.swift` |
| Mail | switch-glass | Mail 40 | `App/Mail/InboxLane.swift` |
| Mail | lane-header: Ordnertitel medium, ohne Zähler (C.hasCount nie gesetzt) | Mail 42-53, Mail 706 | `App/Mail/MessageLane.swift` |
| Mail | Suchfeld (28, Unterstrich ink, Platzhalter „In allen Ordnern suchen“/„In X suche | Mail 44-45, Mail 708-710 | `App/Mail/MessageLane.swift`, `App/Components/InputField.swift` |
| Mail | Bereichsknopf „Überall“/„Nur X“ (24, max. 50 % Breite mit Auslassung, Polster 0  | Mail 46, Mail 710 | `App/Mail/MessageLane.swift`, `App/Components/TextButton.swift` |
| Mail | Filter-Kapsel (Symbol; an: inv; ab 340 mit Text) + Menü Alle/Ungelesen/Mit Anhan | Mail 55, Mail 714-715 | `App/Mail/MessageLane.swift` |
| Mail | Such-Schalter „In der Liste suchen“/„Suche schließen“ | Mail 716-717 | `App/Mail/MessageLane.swift` |
| Mail | Kachel-Schalter „Als Kacheln/Als Liste“ (ab 320 oder an) | Mail 770 | `App/Mail/MessageLane.swift` |
| Mail | „X groß“/„Zurück“, „X falten“ | Mail 771-772 | `App/Mail/MessageLane.swift` |
| Mail | Auswahlmodus: „N gewählt“, Alle wählen/Auswahl leeren, Gelesen/ungelesen, Archiv | Mail 718-726 | `App/Mail/MessageLane.swift` |
| Mail | card-notice Ausfall „X ist nicht erreichbar“ + „Erneut verbinden“ | Mail 58-66, Mail 737 | `App/Mail/MessageLane.swift`, `App/Components/Notice.swift` |
| Mail | card-notice „Keine Verbindung“ (warning ink-2) | Mail 738 | `App/Mail/MessageLane.swift` |
| Mail | card-notice „Postausgang nicht gesichert“ | Mail 740 | `App/Mail/MessageLane.swift` |
| Mail | content-state lädt (Spinner im Ring, „Nachrichten werden geladen\n12 von 50“) | Mail 69-77, Mail 729 | `App/Mail/MessageLane.swift`, `App/Components/ContentPlaceholder.swift` |
| Mail | content-state nicht verbunden (+ „Postfach verbinden“ Akzent) | Mail 730 | `App/Mail/MessageLane.swift` |
| Mail | content-state Fehler (+ „Erneut versuchen“ neutral, „Zuletzt geladen …“) | Mail 731 | `App/Mail/MessageLane.swift` |
| Mail | content-state keine Treffer Suche / Filter | Mail 733-734 | `App/Mail/MessageLane.swift` |
| Mail | content-state leer je Ordner (+ „Neue Mail“ nur Eingang/Gesendet/Entwürfe/Alle) | Mail 735 | `App/Mail/MessageLane.swift`, `Sources/Mail/State/InboxState+Presentation.swift` |
| Mail | Kopfzeile „N Treffer in allen Ordnern“ | Mail 768 | `App/Mail/MessageLane.swift` |
| Mail | message-row (Polster 12 8, gap 20, Radius row, gewählt --c-inv, Hover/Menü Ring  | Mail 104, Mail 747-749, Mail 520 | `App/Mail/InboxRow.swift`, `App/Components/MessageRow.swift` |
| Mail | Zeilenmarke (ungelesen gefüllt inv/on-inv, sonst Ring cLs Schrift c2, gepickt Ha | Mail 105, Mail 749, Mail 520 | `App/Mail/InboxRow.swift`, `App/Components/Mark.swift` |
| Mail | Absenderzeile (20 hoch; 600/500; Verlaufszähler c3; Fähnchen 12 c2; Datum klein  | Mail 107-113, Mail 750 | `App/Mail/InboxRow.swift` |
| Mail | Betreff (Farbe/Gewicht je ungelesen; „Kein Betreff“) | Mail 114, Mail 751 | `App/Mail/InboxRow.swift` |
| Mail | Vorschau (light, 2 Zeilen, „Kein Text“) | Mail 115, Mail 751 | `App/Mail/InboxRow.swift` |
| Mail | Statuszeile Postausgang | Mail 761-762 (preFg signal nur faile | `App/Mail/InboxRow.swift` |
| Mail | Anhang-Chips (24, Ring cLs, klein c2, 2/3 je Breite, Name Mitte 26) + „+N“ | Mail 117-121, Mail 742, Mail 748 | `App/Mail/InboxRow.swift`, `App/Components/Chip.swift`, `App/Components/Counter.swift` |
| Mail | row-actions bei Hover (oben 12, rechts 8, gap 4, links 8 mit Zeilenfläche) | Mail 124-128 | `App/Mail/InboxRow.swift` |
| Mail | Farbe der Zeilenaktionen | Mail 126 (color:{{ r.c2 }} für alle; | `App/Mail/InboxRow.swift` |
| Mail | Papierkorb-Ordner: Pille „Endgültig löschen?“/„Löschen“ | Mail 126, Mail 756 | `App/Mail/InboxRow.swift` |
| Mail | Aktionen an Postausgang-Zeilen | Mail 763-765 | `App/Mail/InboxRow.swift` |
| Mail | Inline-Bestätigung „Ungeprüft senden?“/„Ja“ | Mail 116, Mail 764 | `App/Mail/InboxRow.swift` |
| Mail | Trennlinie (links 56, rechts 8; nicht an/vor gewählter Zeile) | Mail 135, Mail 752 | `App/Components/MessageRow.swift`, `App/Mail/MessageLane.swift` |
| Mail | „Mehr laden“/„Lädt …“ (quiet, 28, oben 16 unten 8) | Mail 140, Mail 739 | `App/Mail/MessageLane.swift` |
| Mail | Listenfenster 60 + 120, Platzhalter 88 je Zeile | Mail 743-744 | `App/Mail/MessageLane.swift` |
| Mail | Kachelraster (minmax 232, gap 8, Polster 8) | Mail 80, Mail 768, Mail 801 | `App/Mail/MessageTiles.swift`, `App/Components/OverviewGrid.swift` |
| Mail | Kachel (176, Radius row, well, Ring ink-3 gewählt / line, Hover −2 px) | Mail 82, Mail 812-814 | `App/Components/OverviewTile.swift` |
| Mail | Kachelkopf (Marke + Ungelesen-Punkt mit Ring well, Titel medium, Datum klein ink | Mail 83-88 | `App/Components/OverviewTile.swift` |
| Mail | Kachelinhalt (Betreff 2 Zeilen 1.35, Vorschau ink-2 4 Zeilen 1.5, Polster 4 16 4 | Mail 89-92 | `App/Components/OverviewTile.swift` |
| Mail | Kachelaktionen Antworten/Archivieren/Papierkorb (lane, Ring, unten rechts, +6 px | Mail 93, Mail 801 | `App/Mail/MessageTiles.swift`, `App/Components/OverviewTile.swift` |
| Mail | Streifen gefaltete Mitte (Initialen, Punkt ungelesen, n = (h−24−96)/36) | Mail 656-660 | `Sources/Mail/State/InboxState+Strip.swift` |
| Mail | switch-glass | Mail 145 | `App/Mail/InboxLane.swift` |
| Mail | Stapelkopf 44, gap 4, Polster 0 8, zwei Gruppen, Teiler 1×20 Rand 0 4 | Mail 147-151 | `App/Components/CommandHead.swift` |
| Mail | Kopfknöpfe neutral ink-2 / signal, Hover Fläche hover, aus .4 | Mail 148, Mail 878 | `App/Components/CommandHead.swift` |
| Mail | Verwerfen-Pille „Entwurf verwerfen?“/„Verwerfen“ | Mail 887 | `App/Mail/StackLane.swift` |
| Mail | leere Karte (Radius card, lane, Ring line) | Mail 153 | `App/Components/CardStack.swift` |
| Mail | Karte: vorn lane, hinten Stufen grau, oben Radius card, unten 0, Lackschatten | Mail 155, Mail 786-788, Mail 624-633 | `App/Components/CardFace.swift`, `App/Components/View+Lacquer.swift` |
| Mail | hintere Karte Hover −4 px (stackLift) | Mail 785, Mail 916 | `App/Components/CardFace.swift` |
| Mail | Übersicht offen: Karten blenden aus und sinken 8 px | Mail 785 (tf: translateY(8px)), Mail | `App/Components/CardStack.swift` |
| Mail | card-header 44, gap 8, Polster 0 8, Haarlinie nur vorn | Mail 156 | `App/Components/CardHeader.swift` |
| Mail | Kartenmarke (28, mr 12, Ring 22 %; Entwurf compose, ohne Initialen person) | Mail 157-160, Mail 790 | `App/Components/CardHeader.swift`, `App/Mail/MessageCard+Head.swift` |
| Mail | Kartentitel (Nachricht Name, vorn Klick → Personenmenü; Entwurf „An X“/„Neue Nac | Mail 161, Mail 781, Mail 796 | `App/Mail/MessageCard+Head.swift` |
| Mail | Meta vorn Nachricht: Adresse Mitte 36, klein, .72 | Mail 162, Mail 782, Mail 785 | `App/Mail/MessageCard+Head.swift` |
| Mail | Meta hintere Nachricht: Datum | Mail 162 (keine Farbe, erbt Kartenti | `App/Mail/MessageCard+Head.swift` |
| Mail | Meta Entwurf vorn: Status („Entwurf gesichert“, „Sendet …“, „Nicht gesendet“ …) | Mail 162, Mail 782 | `App/Mail/MessageCard+Head.swift` |
| Mail | Meta Entwurf hinten „und N weitere“ | Mail 782 | `App/Mail/MessageCard+Head.swift` |
| Mail | Anheften (nur Vorschaukarte, „Anheften · bleibt im Stapel“, .7 → 1 + hover) | Mail 164, Mail 795 | `App/Mail/MessageCard+Head.swift`, `App/Components/CardHeadButton.swift` |
| Mail | Schließen (.7 → 1, ohne Fläche; während „Sichert …“ gesperrt) | Mail 165, Mail 792 | `App/Mail/MessageCard+Head.swift` |
| Mail | Empfängerzeile Lesen (36, „An“ 40, Disclosure 28 −8/8, Chevron 12 ink-3, offen „ | Mail 171-175, Mail 818 | `App/Mail/RecipientDetail.swift`, `App/Components/Disclosure.swift` |
| Mail | Empfängerliste (44, Spalten 40/24, An/Cc, Marke 24 ink-2 lane Ring, max 308, Hov | Mail 176 | `App/Mail/RecipientDetail.swift`, `App/Mail/RecipientRow.swift` |
| Mail | Lesebogen (Rand 0 8 8, Polster 16 8 24, Radius row, sheet/sheet-ink, hell) | Mail 179 | `App/Mail/SheetDetail.swift` |
| Mail | Schrift des Lesebogens | Mail 179 (font-family: var(--typogra | `App/Mail/SheetDetail.swift`, `App/Mail/ThreadItemRow.swift`, `App/Mail/AttachmentRow.swift`, `App/Components/Notice.swift` |
| Mail | Betreff (title 18, 1.25, medium, tracking title) | Mail 180 | `App/Mail/SheetDetail.swift` |
| Mail | „N Nachrichten in dieser Unterhaltung“ (klein, sheet-ink-3, oben 4) | Mail 181, Mail 822 | `App/Mail/SheetDetail.swift` |
| Mail | Hinweis „Externe Bilder blockiert“ + „Bilder laden“ (sheet-well, Rand 16 −8 0) | Mail 182-187 | `App/Mail/SheetDetail.swift`, `App/Components/Notice.swift`, `App/Components/TextButton.swift` |
| Mail | Verlaufskopf (Name medium als Knopf → Menü, Datum klein sheet-ink-3, „Heute, hh: | Mail 189-190, Mail 828 | `App/Mail/ThreadItemRow.swift` |
| Mail | Verlaufstrenner (oben 16, ab 2. Eintrag 16 + Haarlinie) | Mail 189, Mail 830 | `App/Mail/ThreadItemRow.swift` |
| Mail | Verlaufstext (pre-wrap) | Mail 191 | `App/Mail/ThreadItemRow.swift` |
| Mail | image-tile (2 Spalten, Seitenverhältnis imageTile, blockiert gestreift „Bild blo | Mail 192-196, Mail 831 | not built |
| Mail | quote-toggle (24, Polster 0 8, klein medium, tracking control, sheet-ink-2, Ring | Mail 198 | `App/Mail/ThreadItemRow.swift` |
| Mail | Zitat (links 12, Balken 2 sheet-line, sheet-ink-3) | Mail 199 | `App/Mail/ThreadItemRow.swift` |
| Mail | Anhangzeilen Lesen (40, gap 12, Kapsel, Hover sheet-well, Kasten 28 Radius notic | Mail 202-212, Mail 832 | `App/Mail/ThreadItemRow.swift`, `App/Mail/AttachmentRow.swift` |
| Mail | card-footer (44, Haarlinie oben, Gruppen gap 4, Polster 0 8) | Mail 285-289 | `App/Mail/MessageCard+Foot.swift` |
| Mail | Farbe der Fußknöpfe (Drucken, Als PDF sichern, In Projektordner sichern, Datei a | Mail 286, Mail 288, Mail 878 (neutra | `App/Mail/MessageCard+Foot.swift` |
| Mail | „Senden“ (Akzent, Text ab 300, aus .4) | Mail 288, Mail 892 | `App/Mail/MessageCard+Foot.swift`, `App/Mail/StackLane.swift` |
| Mail | drop-overlay „Loslassen hängt an“ (8 innen, Radius notice, gestrichelt ink-3, we | Mail 222-224 | `App/Mail/DraftEditor.swift` |
| Mail | Hinweis „Nicht gesendet“ + „Erneut senden“ | Mail 226-231, Mail 853 | `App/Mail/DraftEditor.swift` |
| Mail | Hinweis „Senden braucht die Schreibfreigabe“ (warning) | Mail 858 | `App/Mail/DraftEditor.swift` |
| Mail | Hinweis „Mail zu groß“ + „Anhänge ändern“ | Mail 854 | not built |
| Mail | Hinweise „Entwurf nicht gesichert“ (Server/Anmeldung) | Mail 855-856 | `App/Mail/DraftEditor.swift` |
| Mail | Von-Zeile (44, Etikett 48, ohne Abstand, Knopf −8/8, Name medium + Adresse klein | Mail 233-237 | `App/Mail/DraftEditor.swift`, `App/Mail/AddressButton.swift` |
| Mail | Von-Menü (Konten ✓, Trenner, „Keine Signatur“, Signaturname ✓, „Signaturen bearb | Mail 840 | `App/Mail/DraftEditor.swift` |
| Mail | An-Zeile (44, Etikett 40, Chips gap 4, Eingabe min 64 links 4) | Mail 239-248 | `App/Mail/RecipientEditor.swift` |
| Mail | Chip (24, Polster 0 4 0 8, Ring line-strong, Entfernen 16 mit 10er Kreuz ink-3) | Mail 243 | `App/Components/Chip.swift` |
| Mail | Cc/Bcc-Schalter (people, an: inv) | Mail 247, Mail 841 | `App/Mail/RecipientEditor.swift` |
| Mail | Sammelzeile bei ›2 Empfängern („Vorname“ + „und N weitere“ + Chevron, Tip „Alle  | Mail 244, Mail 459, Mail 838 | `App/Mail/RecipientEditor.swift` |
| Mail | offene Sammelzeile („N Empfänger“, „Weniger zeigen“) | Mail 245 | `App/Mail/RecipientEditor.swift` |
| Mail | Empfängerliste mit Entfernen (24, Hover ink + sel, .92) | Mail 252 | `App/Mail/RecipientEditor.swift` |
| Mail | Eingabezeile (36, gestrichelter Kreis 24 mit +, „Empfänger hinzufügen“) | Mail 252 | `App/Mail/RecipientEditor.swift` |
| Mail | Vorschläge (44, Spalten 24/1fr/auto, gap 12, Tag „Kontakt“/„Absender“) | Mail 249-251, Mail 837 | `App/Mail/RecipientEditor.swift`, `App/Mail/SuggestionRow.swift` |
| Mail | Cc/Bcc-Zeilen („Kopie“/„Blindkopie“) | Mail 841 | `App/Mail/RecipientEditor.swift` |
| Mail | Betreffzeile (44, Etikett 40, gap 8, medium, links 4) | Mail 256-260 | `App/Mail/DraftEditor.swift` |
| Mail | Schreibbogen (Rand 8, min 192, Radius row, sheet; Text min 120, Polster 16 8 8,  | Mail 262-263 | `App/Mail/DraftEditor.swift`, `App/Mail/BodyEditor.swift` |
| Mail | mail-signature (24-px-Strich sheet-line-strong, Name medium sheet-ink, Zeile she | Mail 264-268 | `Sources/Mail/State/InboxState+Signature.swift` |
| Mail | Anhang-Chips im Entwurf (Polster 0 16 8, Name Mitte 34 + Größe ink-3 + Entfernen | Mail 270-274, Mail 848 | `App/Mail/DraftEditor.swift` |
| Mail | formatting-bar (44, gap 4, Polster 0 8, Haarlinie oben, 6 Knöpfe ink-2) | Mail 276-280, Mail 846 | `App/Mail/FormatRow.swift` |
| Mail | card-overview (lane, über den Karten, blendet ein) | Mail 294, Mail 799 | `App/Mail/StackLane.swift`, `App/Mail/OverviewList.swift`, `App/Components/CardStack.swift` |
| Mail | Übersichtsraster (176, minmax 232, gap 8) | Mail 295-297 | `App/Mail/OverviewList.swift`, `App/Components/OverviewGrid.swift` |
| Mail | Eintritt der Übersichtskacheln | Mail 297, Mail 802 (Verzug 24 ms × m | `App/Components/OverviewTile.swift` |
| Mail | heiße/andere Kachel (−3 px 1.012 / .988, .55, Schatten) | Mail 802 | `App/Components/OverviewTile.swift` |
| Mail | Entwurfskachel (Datum „Entwurf“, Betreff oder „Ohne Betreff“, Text als Vorschau, | Mail 806 | `App/Mail/OverviewList.swift` |
| Mail | Schließen und Aktionen an Übersichtskacheln | Mail 302, Mail 308, Mail 801 | `App/Mail/OverviewList.swift` |
| Mail | Streifen gefaltete rechte Bahn (ohne Karten „Neue Mail“; vorn Nachricht: Antwort | Mail 661-665 | `Sources/Mail/State/InboxState+Strip.swift` |
| Mail | toast (28, Polster 0 12, Kapsel inv, klein, gap 12, Fehlersymbol −4, sh-float) | Mail 314 | `App/Components/ToastView.swift`, `App/Mail/MailToast.swift` |
| Mail | Toast-Knopf „Rückgängig“/„Erneut versuchen“ (20, Polster 0 8, control, Ring curr | Mail 314, B:112-113 | `App/Components/ToastView.swift` |
| Mail | Toast nach „In Projektordner sichern“ | Mail 510 | `Sources/Mail/State/InboxState+Files.swift`, `Sources/Mail/Model/Toast.swift` |
| Mail | anchored-menu (Polster 4, Radius contextMenu, menu, sh-float; Zeile 28 Polster 0 | Mail 323-329, B:152 | `App/Components/AnchoredMenu.swift`, `App/Components/MenuPanel.swift` |
| Settings | Leading lane header (no title, fold button only) | Einstellungen 16-20, Einstellungen 3 | `App/Settings/SettingsPane.swift` |
| Settings | Group rows Ich/Firma/Dateiordner/Verbindungen/Schutz und System with symbols | Einstellungen 25-29, Einstellungen 2 | `App/Settings/SettingsPane.swift`, `App/Components/LaneRow.swift` |
| Settings | Failure counter on Verbindungen | Einstellungen 28, Einstellungen 390 | `App/Settings/SettingsPane.swift` |
| Settings | Click on a group | Einstellungen 390 (go: setState({cat | `Sources/Hub/State/SettingsState.swift` |
| Settings | Centre header title = category / active tile group | Einstellungen 39, Einstellungen 403- | `App/Settings/SettingsPane.swift`, `App/Settings/IntegrationList.swift` |
| Settings | Strip marks of folded lanes | Einstellungen 365-375 | `App/Settings/SettingsPane.swift` |
| Settings | Scrollbars of tiles, centre rows, card content | Einstellungen 47, Einstellungen 49,  | `App/Settings/IntegrationList.swift`, `App/Settings/SettingsPane.swift`, `App/Settings/SettingsStack.swift` |
| Settings | Tile group label (0 high for first group, 24 for others, fades when active) | Einstellungen 47, Einstellungen 404 | `App/Settings/IntegrationList.swift` |
| Settings | Last group min height 100cqh+32 | Einstellungen 404 | `App/Settings/IntegrationList.swift` |
| Settings | Tile grid auto-fill minmax(settingsTileMinWidth), gap 8 | Einstellungen 47 | `App/Settings/TileFlowLayout.swift`, `App/Settings/IntegrationList.swift` |
| Settings | Settings tile body (112 high, pad 8, radius row, well / selected ink+lane, name  | Einstellungen 47, Einstellungen 401 | `App/Settings/SettingsTile.swift` |
| Settings | Tile hover | Einstellungen 47 style-hover: box-sh | `App/Settings/SettingsTile.swift` |
| Settings | Tile press scale .98 | Einstellungen 47 | `App/Settings/SettingsTile.swift` |
| Settings | Tile mark 28 circle, logo on #fff, initial, ring lane/line-strong | Einstellungen 47, Einstellungen 401 | `App/Settings/SettingsTile.swift` |
| Settings | Service "DHL" (one tile; fields Tracking-Schlüssel, Versand-Schlüssel, Secret, B | Bausteine 43 | `Sources/Hub/Store/IntegrationCatalogStore.swift` |
| Settings | Service "Happa Happa" (Speiseplan, Schlüssel) | Bausteine 44 | `Sources/Hub/Store/IntegrationCatalogStore.swift` |
| Settings | Service purpose line (hero subtitle) | Bausteine 37, :41, :42, :43 | `App/Settings/IntegrationHero.swift` |
| Settings | Keys tile "Schlüssel-Inventar", sub empty | Einstellungen 236 (schluessel: ["Sch | `App/Settings/IntegrationList.swift` |
| Settings | Profile tile (pad 16, radius row, well / selected inv, no ring, press .99) | Einstellungen 50, Einstellungen 416 | `App/Settings/ProfileTile.swift` |
| Settings | Profile mark 56 (title size, tracking-mark) | Einstellungen 51 | `App/Settings/ProfileTile.swift` |
| Settings | Profile name (title size, line-height heading 24, no letter-spacing) | Einstellungen 51 | `App/Settings/ProfileTile.swift` |
| Settings | "Bild wählen" capsule button in profile tile | Einstellungen 51 | not built |
| Settings | Facts grid (Kürzel, Telefon, Teams; minmax(140px,1fr), gap 12/16; value in tile  | Einstellungen 52, Einstellungen 416 | `App/Settings/ProfileTile.swift` |
| Settings | Fact "Teams" | Einstellungen 416 | not built |
| Settings | "Adressen" list | Einstellungen 53 | `App/Settings/ProfileTile.swift` |
| Settings | Section rows (message-row: mark 28, pad 12/8, gap 20, two lines, separator from  | Einstellungen 58-75, Einstellungen 4 | `App/Settings/SectionRow.swift`, `App/Components/MessageRow.swift` |
| Settings | Row value slot ("Automatisch" on Darstellung) | Einstellungen 70, Einstellungen 410 | `App/Settings/SectionRow.swift`, `App/Settings/SettingsPane.swift` |
| Settings | Row "Ordnerschema" (detail "") in Dateiordner | Einstellungen 236 (einrichtung: ["Or | `Sources/Hub/Model/SettingsSection.swift` |
| Settings | Stack command head: Verbinden/Erneut verbinden (link), Trennen (close, signal),  | Einstellungen 86-90, Einstellungen 4 | `App/Settings/SettingsCommandHead.swift` |
| Settings | Empty stack card "Leere Karte" | Einstellungen 92 | `App/Components/CardStack.swift` |
| Settings | Card face (border-radius:0, box-shadow:none, no glaze) | Einstellungen 94, Einstellungen 427- | `App/Settings/SettingsStack.swift` |
| Settings | Card top: content starts directly (no header row) | Einstellungen 94-98 (article holds o | `App/Settings/SettingsStack.swift` |
| Settings | Card content: pad 4/8, bottom corners masked (radius-row, 8 inset) | Einstellungen 98 | `App/Settings/SettingsStack.swift` |
| Settings | Card overview (Klein/Mittel/Groß, tiles with mark, title, close, sub, state) | Einstellungen 139-164, Einstellungen | `App/Settings/SettingsStack.swift` |
| Settings | Service hero (56 well/logo box, radius contextMenu, name title + line-height hea | Einstellungen 100, Einstellungen 302 | `App/Settings/IntegrationHero.swift` |
| Settings | Block head (list-section-header-3, 36, pad 0/16/8) | Einstellungen 101 | `App/Settings/BlockHead.swift` |
| Settings | Note | Einstellungen 102 | `App/Settings/BlockHead.swift` |
| Settings | Card notice | Einstellungen 104-109, Bausteine 184 | `App/Settings/IntegrationCard.swift`, `App/Components/Notice.swift` |
| Settings | Field row (min 44, pad 8/8/8/16, label min fieldLabelMinWidth, hairline inset 16 | Einstellungen 113-117, Einstellungen | `App/Settings/SettingsRow.swift` |
| Settings | Spacing between trailing controls (row gap: step12; status text padding-right: s | Einstellungen 113, Einstellungen 121 | `App/Settings/SettingsRow.swift`, `App/Settings/SettingsDetail.swift`, `App/Settings/AccountBlock.swift` |
| Settings | Overflow of trailing values (input/value/pill max-width:60%, ellipsis, one line) | Einstellungen 124-127 | `App/Settings/SettingsRow.swift` |
| Settings | Value size 12px for secrets and Version/Zweig | Einstellungen 312 (vSize: "12px"), E | `App/Settings/SettingsRow.swift` |
| Settings | Input field (right-aligned, h 28, pad-right 12) | Einstellungen 124 | `App/Settings/ValueField.swift`, `App/Settings/AddEditor.swift` |
| Settings | Choice pill (h 28, pad 0/8/0/12, ring line-strong, chevron 12/1.5) | Einstellungen 127 | `App/Settings/SettingsRow.swift` |
| Settings | Segmented control | Einstellungen 128 | `App/Components/SegmentedControl.swift` |
| Settings | Confirm pill in row (96 wide, -offset) | Einstellungen 129 | `App/Settings/View+RowPill.swift` |
| Settings | Toggle 32×20, knob 16 | Einstellungen 129, Bausteine 183 | `App/Components/ToggleSwitch.swift` |
| Settings | Text buttons accent/neutral/signal/plain | Einstellungen 107, Einstellungen 130 | `App/Components/TextButton.swift` |
| Settings | Connection status (dot 8, ring, spinner, colours per state) | Einstellungen 65-68, Einstellungen 1 | `App/Components/ConnectionStatus.swift` |
| Settings | Toast capsule over the right lane | Einstellungen 170, Einstellungen 516 | `App/Settings/SettingsToast.swift`, `App/Components/ToastView.swift`, `App/Shell/Frame.swift` |
| Settings | Anchored menu (pad 4, rows 28, check column 12, head 24, separator) | Einstellungen 174-180, Bausteine 114 | `App/Components/AnchoredMenu.swift`, `Sources/Shell/Logic/MenuWidthEngine.swift` |
| Settings | Row "Zustand" with status and sub (geprüft / Fehler / Anmeldung läuft) | Einstellungen 301, Einstellungen 304 | `App/Settings/IntegrationCard.swift` |
| Settings | Sub "Projekte 412 von 1.280" while working | Einstellungen 301 | not built |
| Settings | Failure notice "Fehler · …" + "Erneut verbinden" | Einstellungen 305 | `App/Settings/IntegrationCard.swift` |
| Settings | Keychain notice + "Neu eintragen" | Einstellungen 306 | `App/Settings/IntegrationCard.swift` |
| Settings | Disconnect notice "X trennen?" + Trennen / Abbrechen | Einstellungen 307 | `App/Settings/IntegrationCard.swift` |
| Settings | Head "Postfächer" | Einstellungen 268 | `App/Settings/AccountBlock.swift` |
| Settings | Notice "Noch kein Mail-Konto." + accent "Konto hinzufügen" | Einstellungen 270 | `App/Settings/AccountBlock.swift` |
| Settings | Account row (label display name, sub provider, status, line false) | Einstellungen 269 | `App/Settings/AccountBlock.swift` |
| Settings | "Name in Mail" input | Einstellungen 292 | `App/Settings/MailboxNameRow.swift` |
| Settings | "Angezeigt als" pill (own name / local@ / @domain) | Einstellungen 293 | `App/Settings/MailboxDisplayRow.swift` |
| Settings | "Bilder in Mails laden" toggle per account (and for Google) | Einstellungen 269, Einstellungen 309 | `App/Settings/MailboxImagesRow.swift`, `App/Settings/AccountBlock.swift`, `App/Settings/IntegrationCard.swift` |
| Settings | Signature block (head "Signatur · …", textarea, 2 toggles, "Signatur entfernen"  | Einstellungen 111, Einstellungen 251 | `App/Settings/SignatureBlock.swift` |
| Settings | Signature empty: note + accent "Signatur anlegen" | Einstellungen 254 | `App/Settings/SignatureBlock.swift` |
| Settings | "Konto entfernen" confirm | Einstellungen 269 | `App/Settings/AccountBlock.swift` |
| Settings | Row with neutral "Konto hinzufügen" (label "", line false) | Einstellungen 270 | `App/Settings/AccountBlock.swift` |
| Settings | Add form "Anbieter" pill: Gmail, GMX, IONOS, default "Wählen" | Einstellungen 272 | `App/Settings/AddEditor.swift`, `Sources/Mail/Logic/ProviderPresets.swift` |
| Settings | Add form fields: Anzeigename, Server Eingang, Port, Verschlüsselung (Keine / SSL | Einstellungen 266, Einstellungen 272 | `App/Settings/AddEditor.swift`, `Sources/Mail/Adapter/IMAPAccess.swift` |
| Settings | Check result notice "Prüfung · Es fehlen: …" | Einstellungen 273, Einstellungen 277 | `App/Settings/AddEditor.swift` |
| Settings | Form buttons "Konto hinzufügen" accent + "Abbrechen" plain | Einstellungen 274 | `App/Settings/AddEditor.swift` |
| Settings | Block "Lokale Ablage": Zeitraum (30 Tage/90 Tage/1 Jahr/Alles), Anhänge lokal, O | Einstellungen 257-264, Einstellungen | not built |
| Settings | Row "Anmeldung" (… · persönlich / · für die Firma) | Einstellungen 311 | `App/Settings/IntegrationCard.swift` |
| Settings | Field value rows (masked / "Nicht eingetragen") | Einstellungen 312 | `App/Settings/IntegrationCard.swift` |
| Settings | "Modell" pill Standard/Sonnet/Haiku/Opus | Einstellungen 312 | `App/Settings/IntegrationCard.swift` |
| Settings | "Zähler" with confirm pill "Zurücksetzen?" | Einstellungen 291 | `App/Settings/UsageBlock.swift` |
| Settings | Verbrauch: tokens row, two price inputs, "Geschätzt" | Einstellungen 283-290 | `App/Settings/UsageBlock.swift` |
| Settings | Google: Name in Mail, Angezeigt als, signature after the fields | Einstellungen 315 | `App/Settings/IntegrationCard.swift` |
| Settings | Abgleich rows: sub, cadence pill, "Jetzt abgleichen" | Einstellungen 316-320 | `App/Settings/IntegrationCard.swift`, `Sources/Hub/Model/Cadence.swift` |
| Settings | "Projektordner" pill and drive menu (head "Laufwerk", Mein Drive / Geteiltes Dri | Einstellungen 321, Bausteine 134, Ba | `App/Settings/ProjectRootRows.swift` |
| Settings | "Drive-Ordner der Projekte" + "Jetzt abgleichen" (after a folder is chosen) | Einstellungen 321 | `App/Settings/ProjectRootRows.swift` |
| Settings | "Zwischenspeicher" + "Leeren", toast "Zwischenspeicher · geleert" | Einstellungen 321 | `App/Settings/IntegrationCard.swift` |
| Settings | Identität: Name, Rolle, Kürzel, Telefon as read-only values | Einstellungen 327 | `App/Settings/IdentityCard.swift` |
| Settings | "Geburtstag im Team zeigen" toggle | Einstellungen 327 | `App/Settings/IdentityCard.swift` |
| Settings | Head "Konto", "Auf diesem Mac abmelden" with sub and confirm | Einstellungen 295, Einstellungen 327 | `App/Settings/IdentityCard.swift` |
| Settings | "Erscheinung" segmented Hell/Dunkel/Automatisch (pill when narrow) | Einstellungen 330, Einstellungen 458 | `App/Settings/AppearanceCard.swift` |
| Settings | "Fremde Inhalte · Immer hell" (line false) | Einstellungen 330 | `App/Settings/AppearanceCard.swift` |
| Settings | "Beim Öffnen" pill (line false) | Einstellungen 331 | `App/Settings/AppearanceCard.swift` |
| Settings | "App-Sperre" toggle | Einstellungen 332 | `App/Settings/AppearanceCard.swift` |
| Settings | "Sperren nach" pill (line false, last row) | Einstellungen 332 | `App/Settings/AppearanceCard.swift` |
| Settings | Datenschutz "Bilder in Mails laden" with explanation sub (on / off text) | Einstellungen 329 | `App/Settings/SettingsDetail.swift` |
| Settings | "Assistent ganz aus", "Dateien im Chat" | Einstellungen 329 | `App/Settings/SettingsDetail.swift` |
| Settings | "Eigene Daten exportieren" + "Exportieren", toast "Export gespeichert." | Einstellungen 329 | not built |
| Settings | Firmendaten inputs Firma/Anschrift/Telefon/Web/Mail (last line false) | Einstellungen 294, Einstellungen 340 | `App/Settings/SettingsDetail.swift` |
| Settings | Impressum inputs Urheber/Rechte/Signatur (last line false) | Einstellungen 342 | `App/Settings/SettingsDetail.swift` |
| Settings | Ordnerschema values Projektordner / Projektdaten / Vorlagen | Einstellungen 335 | `App/Settings/SettingsDetail.swift` |
| Settings | Row "Einrichtung" + "Erneut durchgehen" | Einstellungen 335 | not built |
| Settings | Vorlagen: template rows with remove confirm, "Vorlage anlegen" + "Anlegen" | Einstellungen 341, contract/views.js | `App/Settings/SettingsDetail.swift` |
| Settings | System: Version, Zweig, Datenbank, Diagnose + "Kopieren", toast | Einstellungen 336 | `App/Settings/SystemCard.swift` |
| Settings | Schlüssel-Inventar: status per service + "Entfernen" plain | Einstellungen 343 | `App/Settings/SettingsDetail.swift` |
| Settings | Project folder toasts: chosen "Projektordner · ‹Laufwerk› · ‹Ordner›"; synced "P | Einstellungen 321, Bausteine 140, Ba | `App/Settings/ProjectRootRows.swift`, `App/Settings/SettingsToast.swift` |
| Settings | Toast "Abgemeldet · die App startet neu" | Einstellungen 327 | `App/Settings/IdentityCard.swift` |
| Settings | Area badge = failed services | Einstellungen 507 | `App/Settings/SettingsPane.swift` |
