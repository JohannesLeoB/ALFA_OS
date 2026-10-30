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

| Folder | Content | Rule |
|---|---|---|
| `Model/` | value types (struct, enum) | no I/O, no state |
| `Logic/` | pure functions and engines | deterministic, testable without mocks |
| `Port/` | protocols to the outside world | one protocol per file (reviewed) |
| `Adapter/` | implementations of a port: HTTP, IMAP, Keychain, files | the place for I/O |
| `State/` | `@Observable` state for views | I/O only through ports |
| `Store/` | persistence, implements a port | the place for database and file access |
| `Tool/` | assistant tools, Assistant only (check) | one tool per file (reviewed) |

### Names

- One main type per file; the file name is the type name. `utils/check.py` requires only that the file declares some type of that name (check, partial). A file `Type+Aspect.swift` contains a top-level extension of `Type` (check). Other types in the file are small private or nested companions (reviewed).
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
