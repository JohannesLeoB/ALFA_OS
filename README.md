# ALFA

ALFA is a macOS app (bundle `com.johannesleoberger.alfaos`, SwiftUI, App Sandbox on). It contains a mail client (IMAP/SMTP and Gmail), a settings area, an accounts hub that stores connections and credentials, and a Claude assistant with a calculation engine and tools for Google, Airtable, ClickUp, sevDesk, Clockodo and DHL shipping. The window shows two panes: Mail and Settings. The assistant chat opens in the blob (see [ARCHITECTURE.md](ARCHITECTURE.md)).

## Requirements

- macOS 26 and Xcode 26 (Swift tools 6.2, Swift language mode 6)
- `xcodegen` to generate the Xcode project from `project.yml`
- `python3` (standard library only) and `zsh` for the checks
- Network access on the first build: Swift Package Manager fetches GRDB 6.29.3

## Build, test, run

```
swift build
swift test
python3 -I utils/check.py
zsh utils/check_modules.sh
xcodegen generate
xcodebuild -project ALFA_OS.xcodeproj -scheme ALFA_OS -destination 'platform=macOS' build
zsh utils/build_app.sh
```

- `swift build` and `swift test` build and test all modules in `Package.swift`.
- `python3 -I utils/check.py` checks the code schema, the Markdown files, the generated tokens and the text catalog.
- `zsh utils/check_modules.sh [Module ...]` compiles each module with `swiftc` and runs its test class; with `App` it also typechecks the app. It needs no Swift Package Manager run.
- `zsh utils/build_app.sh` runs xcodegen and xcodebuild and writes the app to `dist/ALFA_OS/ALFA_OS-<version>.app`; the version comes from `project.yml`. Open that file to run the app.
- `git config core.hooksPath .githooks` activates the pre-commit and commit-msg hooks.
- `python3 -I utils/generate_tokens.py` regenerates `Sources/Design/Model` from `Resources/tokens.json`; `python3 -I utils/merge_strings.py` regenerates `Resources/Localizable.xcstrings` from the `*.localizable.json` files.

## Folder map

| Folder | Content |
|---|---|
| `App` | the macOS target, SwiftUI views only |
| `App/Shell` | app entry, window frame, blob, lanes, `AppSession`, `Assembly` (composition root), `ToolShelf` |
| `App/Mail` | views of the mail pane |
| `App/Settings` | views of the settings pane |
| `App/Components` | shared view components |
| `App/Design` | appearance environment, typeface, view modifiers, `SheetValues` |
| `Sources` | Swift package modules, no UI |
| `Sources/Core` | pure building blocks: app identity, company values, CSV, number and address parsing, logging |
| `Sources/Design` | generated design tokens, colours, moods, shadows, ink sets |
| `Sources/Shell` | desk state, blob placement, lane layout, card stack and command bar logic, app directory |
| `Sources/Storage` | SQLite database (GRDB), migrations, audit and integration log |
| `Sources/Hub` | accounts (inlets), providers, credentials in the Keychain, sign-in, sync, costs, settings, legacy import |
| `Sources/Mail` | IMAP/SMTP clients, MIME, mailbox and outbox stores, inbox state |
| `Sources/Calculation` | cost estimation: anchors, carcass and component engines, learning |
| `Sources/Assistant` | Claude client, conversation engine, model router, tools, chat, notes, todos, journal, memory, privacy |
| `Sources/Integrations/Google` | OAuth, Gmail, Calendar, Contacts, Drive |
| `Sources/Integrations/Airtable` | Airtable client, catalog, stock, anchor rows, write allowlist |
| `Sources/Integrations/ClickUp` | ClickUp client and task board |
| `Sources/Integrations/Sevdesk` | sevDesk client and receipts |
| `Sources/Integrations/Clockodo` | Clockodo client, time entries, bookings |
| `Sources/Integrations/Shipping` | DHL tracking and label requests |
| `Tests` | one `<Module>Tests` folder per module with one test class |
| `Resources` | `tokens.json`, `*.localizable.json`, `Localizable.xcstrings`, `apps.json`, `company.example.json`, fonts, asset catalog, `Info.plist`, entitlements |
| `utils` | checks, generators, build script |
| `.githooks` | pre-commit and commit-msg hooks |
| `.github/workflows` | CI workflow |

## Configuration files

Three JSON files are read from the Application Support folder `ALFA_OS` of the app. With the sandbox on, that folder is inside the app container. A missing file leaves the dependent feature inert.

- `~/Library/Application Support/ALFA_OS/company.json`: a flat object of string values, read by `CompanyValues`. `Resources/company.example.json` lists every key. Keys read by code: `company.address`, `company.phone`, `company.web`, `company.mail.projects` (written once into the company settings when those are empty), and the Airtable names `airtable.base.*`, `airtable.table.*` and `airtable.field.sale_price` (base and table names for the write allowlist, the catalog and the estimation model).
- `~/Library/Application Support/ALFA_OS/google-client.json`: the Google OAuth client, read by `ClientConfigStore`. Keys: `clientID` (required), `clientSecret` (optional). Without it the Google provider is not offered.
- `~/Library/Application Support/ALFA_OS/google-drive.json`: Drive layout, decoded as `DriveConfig`. Keys: `projectsRoot` (folder id), `forbiddenFolderIDs` (array of folder ids that are never written), `offers` with `incomingFolderKeyword`, `outgoingFolderKeyword`, `purchaseOrderFolderKeyword`, `invoiceFolderKeyword`, `offerFolderKeyword`, `orderFolderKeyword`, `prefixes` (object from file name prefix to `OfferDocumentType` raw value), `documentNumberPattern`, `customerNumberPattern`, `versionPattern`.

API keys and passwords are not stored in these files; they live in the Keychain.
