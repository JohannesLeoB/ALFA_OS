# Architecture

## Modules

`Package.swift` declares fourteen library modules and one test target per module. The app target in `project.yml` links all of them. GRDB 6.29.3 is the only external dependency.

| Module | Depends on |
|---|---|
| Core | none |
| Design | none |
| Shell | Design |
| Storage | Core, GRDB |
| Hub | Core, Design, Storage, GRDB |
| Mail | Core, Design, Shell, Storage, Hub, GRDB |
| Calculation | Core, Storage, GRDB |
| Assistant | Core, Storage, Hub, Calculation, GRDB |
| Google | Core, Hub, Mail, Assistant |
| Airtable | Core, Hub, Assistant, Calculation |
| ClickUp | Hub, Assistant |
| Sevdesk | Hub, Assistant, Storage, GRDB |
| Clockodo | Core, Hub, Assistant, Storage, GRDB |
| Shipping | Core, Hub, Assistant |

```
Core, Design                      no dependencies
Shell -> Design
Storage -> Core
Hub -> Storage, Design
Mail -> Hub, Shell, Storage
Calculation -> Storage
Assistant -> Hub, Calculation
Google -> Mail, Assistant
Airtable -> Assistant, Calculation
ClickUp, Sevdesk, Clockodo, Shipping -> Assistant
```

Integrations never depend on each other; they meet in the app. `App` contains views only and depends on every module.

## Schema

`utils/check.py` enforces every rule marked (check).

### Layout

```
App/<Feature>/           SwiftUI views, one folder per area, Swift files directly inside
Sources/<Module>/        modules without UI
Sources/Integrations/<Service>/   Airtable, ClickUp, Sevdesk, Clockodo, Shipping, Google
Tests/<Module>Tests/<Module>Tests.swift   one test class per module
Resources/               tokens, text sources, catalog, fonts, assets, plist
utils/                   checks, generators, build script
```

- Module names (check): Core, Design, Shell, Storage, Hub, Assistant, Mail, Calculation, Catalog, Project, Today, Survey, and the integrations above. Catalog, Project, Today and Survey are reserved for later; no code exists for them.
- A module holds only the subfolders below, no files directly (check). Each subfolder holds Swift files directly (check).

| Folder | Content | Rule |
|---|---|---|
| `Model/` | value types (struct, enum) | no I/O, no state |
| `Logic/` | pure functions and engines | deterministic, testable without mocks |
| `Port/` | protocols to the outside world | one protocol per file |
| `Adapter/` | implementations of a port: HTTP, IMAP, Keychain, files | the place for I/O |
| `State/` | `@Observable` state for views | I/O only through ports |
| `Store/` | persistence, implements a port | the place for database and file access |
| `Tool/` | assistant tools, Assistant only (check) | one tool per file |

### Names

- One main type per file; the file name is the type name (check). A file `Type+Aspect.swift` contains a top-level extension of `Type` (check). Other types in the file are small private or nested companions.
- English, CamelCase, ASCII identifiers (check). No module prefix; a domain prefix only where a name collides with Swift or SDK names.
- Forbidden name words: Manager, Helper, Util, Utils, Utility, Utilities, Service, Services, Handler, Impl, Base, Common, Misc, New, Old, version numbers such as V2, and trailing digits (check). `Base64` is the one allowed digit name.
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

- Folder placement of Client, Engine, Failure, Parser, Port, Store, Tool and State names is checked; the folders Port, Tool, Store and State accept only their own suffix (check).
- View names in `App` are named after the thing, Apple style: `MessageRow`, `DraftEditor`, `InboxLane`, `SettingsCard`. The `View` suffix is used only where a model has the same name. `ButtonStyle`, `ToggleStyle` and `Layout` conformances end in the protocol name. `View+Aspect.swift` holds a private `ViewModifier` and a `View` method.
- View suffixes (Row, List, Detail, Card, Lane, Button, Editor) are not used in `Sources`; the suffixes Client, Store, Engine, Router, Parser, Registry, Tool, Port and Failure are not used in `App` (check).
- `Tests` holds one folder `<Module>Tests` per module with exactly the file `<Module>Tests.swift` (check).

### Content

- No comments of any kind (check).
- No prose in code: user-facing text exists only as keys in `Resources/Localizable.xcstrings`; every key used in code has a value (check).
- No literal colours or numbers in `App` views except 0, 1 and 2; sizes, spacing, radii, durations and every other value come from `Design` tokens or `App/Design/SheetValues.swift` (check).
- The company name never appears in `Sources`, `App`, `Tests` or `utils` (check). Company values reach the app only through the company configuration file (see [README.md](README.md)).
- Markdown: exactly `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md`; every link and repository path in them exists (check).
- Generated files match their generators (check).
- Access: `internal` by default, `public` only across module boundaries. Every `public` member has a caller outside its module. No stubs, no provisional code. These three rules are reviewed, not checked.

## Layering

Dependencies point from the outer layers to the inner ones inside a module:

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

`App/Shell/Assembly.swift` builds every dependency once: it opens the database, runs the legacy import, creates the stores, the provider list (`ProviderPort`), `Connections`, `InboxState`, `ChatStore`, `ToolShelf` and `ConversationEngine`. `App/Shell/AppSession.swift` owns the `Assembly` and the desk state, creates the panes (`mail`, `settings`) and starts mail sync. `App/Shell/AlfaApp.swift` creates the session with `AppSession.live()`. No other file constructs a client or store. `ToolShelf` creates the assistant tools for the integrations whose inlet is connected; `Assembly.reshelve()` rebuilds the registry when inlets change.

## Data

- One SQLite file `alfa.sqlite` in the Application Support folder `ALFA_OS`, opened by `DatabaseStore` with write-ahead logging and foreign keys on.
- Migrations are registered in `SQLiteStore+Migrations.swift` and `SQLiteStore+CalculationMigration.swift` under the names hub, mail, audit, assistant, project, catalog, clockodo, sevdesk and calculation, and run when the database opens.
- Every store takes the `SQLiteStore` through its initializer. Secrets (API keys, passwords) are stored through `KeychainStore`, not in the database.
- `LegacyImportStore` runs at every start but imports once: it reads a legacy `hub.sqlite` next to the database and selected `UserDefaults` values, and then sets the setting `import.legacy.done`. `ReceiptStore.adopt(legacy:)` moves the old receipts out of `UserDefaults`.
- Attachments of chat messages are files in the folder `attachments` next to the database.

## Design tokens

`Resources/tokens.json` is the single source for colours, sizes, spacing, radii, motion, typography and shadows. `utils/generate_tokens.py` reads it and writes `Tokens.swift`, `Colors.swift`, `Moods.swift`, `Shadows.swift` and `InkSet.swift` into `Sources/Design/Model`. `python3 -I utils/generate_tokens.py --check` fails when a generated file differs; `utils/check.py` runs it. Views read tokens through `Tokens`, `Colors`, `Moods`, `Shadows` and `InkSet`; `App/Design/Appearance.swift` selects light or dark values.

## Texts

Each module that has user-facing text owns `Resources/<name>.localizable.json`: keys with a `de` value. `utils/merge_strings.py` merges these files into `Resources/Localizable.xcstrings` (source language `de`) and keeps existing catalog values. `--check` fails when the catalog is stale; it also lists keys used in code (`string(`, `text(`, `format(`, `key(`, `LocalizedStringKey(`, `LocalizationValue(`, and `...Key:` arguments) that have no value. Views resolve text through `Appearance`; engines resolve text through `TextPort`, implemented by `TextStore` in `App/Shell/Assembly.swift`.

## Assistant

- `ClaudeClient` talks to the Anthropic API with the key that `ClaudeCredential` reads from the Keychain slot of the connected `claude` inlet.
- `ConversationEngine` runs a turn: it checks the privacy choices, prepares the conversation (`Grounding`, `MemoryEngine`), selects tools, calls the model, executes tool calls through `ToolRegistry.run` and stores everything in `ChatStore`.
- Tools implement `ToolPort` (`Sources/Assistant/Port/ToolPort.swift`): a name, an access level (`read`, `propose`, `write`), a privacy category, parameters and `run`.
- Privacy categories (`PrivacyCategory`): mail, calendar, contacts, drive, clickUp, notes, tasks, catalogCalculation, studioKnowledge, chat, time. The user disables categories in settings (`PrivacyStore`); `ToolAccessEngine.allowed` removes the tools of a disabled category from the turn. `PrivacyChoices` in Hub adds `assistantOff`, `chatFiles` and `loadImages`.
- Model routing (`ModelRouter`): a request that mentions estimation words uses Opus; otherwise a turn with tools enabled uses Sonnet; otherwise a long or analytical request uses Sonnet; everything else uses Haiku. The model ids are constants in `ModelRouter`; the credential's own model setting defaults to `ClaudeKey.defaultModel`.
- Calculation runs through `CalculationTool`, which wraps `EstimationEngine` from the Calculation module with price anchors (seed, Airtable, learned and PDF-learned).

## Not wired

- The assistant has no view. `Assembly` builds `ConversationEngine`, `ChatStore` and `PrivacyStore`, and the privacy choices appear in settings, but no file in `App` starts a conversation. The chat view is added when its design exists.
- These tools exist and are tested but `ToolShelf` does not register them: `FindOffersTool`, `ListProjectsTool`, `ListSamplesTool`, `LookupCustomerTool`, `ProposeContactTool`, `ProposeFileTool`, `ReadFileTool`, `SearchContactsTool`, `StudioKnowledgeTool`.
- The modules Catalog, Project, Today and Survey do not exist yet.
- `apps.json` lists two apps, Mail and Settings; panes exist for exactly those.
