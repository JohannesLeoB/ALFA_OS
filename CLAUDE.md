@AGENTS.md

# Session start

Binding: the rules in [AGENTS.md](AGENTS.md) (loaded above) and the schema in [ARCHITECTURE.md](ARCHITECTURE.md). Build, run and configuration: [README.md](README.md). This file holds status, decisions and the next tasks; whoever changes them updates it in the same commit.

## Status
- `main` is the rebuild from commit `34c7366` on: 14 modules plus app; `utils/check.py` checks the rules marked (check) in [ARCHITECTURE.md](ARCHITECTURE.md), see next tasks 5 to 12 for the rules the tree does not meet yet.
- The old stand (legacy code, old docs, old agents and memory notes) is fully in tag `archive/before-rebuild`. Read with `git show archive/before-rebuild:<path>`.
- Verified on the Mac: `swift build`, `swift test` (343 tests at the rebuild; `Tests/` now holds 485 test functions, the run was not repeated), `utils/build_app.sh` (28.10.: builds without warnings, app launched once). `utils/check_modules.sh` runs all module tests in the sandbox and fails when a test run crashes.
- Module tests were mutation-tested on 28.10.: 259 mutants, 246 killed; of the 13 survivors 11 are equivalent, 1 needs the keychain (sandbox), 1 was fixed in code (0 % logged as unchanged).
- 29.10.: brief to Design for Projects and the editors handed over as a ZIP (outside git): functions, data and controls per area from `archive/before-rebuild:fundus/alpha/Sources`, with open points.
- Not yet verified: launching the app and the first run with the one-time legacy import, the first CI run on GitHub.
- `main` on GitHub is protected. Johannes' account pushes past it as "Bypassed rule violations"; another account may be rejected. Then adjust the rule in the GitHub settings or work via a pull request.

## Decisions
- Design masters (Johannes 29.10.): only Johannes hands a design master to a session, as a ZIP in that session's chat. Nothing is searched for or taken from other folders, branches or tags. Only such a ZIP is a valid master and reference; it is stored in the repository as the latest and the previous master, and the newest hands over to the next.
- Valid master: `DESIGN/ALFA Design Master 2026-10-28.zip` (28.10., delivered as ALFA-Uebergabe-2810); previous `DESIGN/ALFA Design Master 2026-10-27.zip` (27.10., ALFA-Uebergabe-2710). Views, tokens and texts follow the latest; the bows are the ALFA *.dc.html files and the contract folder inside it. A new master from Johannes replaces the previous one in the same commit that adopts it, and this line names it.
- Work style: read every file before changing it; no blanket cuts or search-and-replace edits; ask before removing anything not proven dead. Old quotes in archived notes are not binding.
- Mail and Hub were rewritten without legacy code; integrations were adopted file by file.
- The Claude assistant (37 tools) and the calculation it drives are kept; calculation numbers and model routing stay unchanged.
- Finished but unwired parts stay `internal` and are not deleted: 9 assistant tools, DHL labels (`LabelClient`, `LabelState`), the Clockodo time table (`TimeTableState`, `BookingEngine`). The calculation learning stores (`LearningStore`, `LearnedAnchorStore`, `PdfAnchorStore`) are wired in `ToolShelf`.
- N20 (Johannes 28.10.): every common mail function is built and shown only when the mailbox can do it technically, never greyed out. Built: move to folder, show original, read receipt, format bar (bold, italic, underline, bullets, numbering, link into bodyHTML). Open: save as template (the design shows no way to use a template); send later stays off.
- The assistant chat follows the delivery of 28.10. (ALFA Shell.dc.html from line 89); `App/Shell/AssistantPanel.swift` with `ChatState` in Sources/Assistant/State. The blob dot (F10) lights when an answer finishes while the assistant is closed.
- Projects (Johannes 29.10.): a project is born in the app, through the "new project" dialog and the questionnaire; Drive, Airtable, ClickUp and local folders are targets chosen as hub routes. The questionnaire questions are in the old lab code, not yet read.
- Editors (Johannes 29.10.): survey, atelier, configurator, plan with plan comparison and moodboard form one module of their own inside the app, like a creative suite. Johannes' mockups from another Design session are the reference; the claude.ai artifacts of 16.10. are not.
- A neutral requirements spec of the old app is drawn up by a separate session outside this one, from sources Johannes names (the brief was handed to Johannes as a file; it is not in the repository).
- On first launch `LegacyImportStore` (Sources/Hub/Store) imports the old Hub database and the old app settings once; the old data is never changed.
- The Airtable sale-price column name comes only from the company configuration (key `airtable.field.sale_price`, see `Resources/company.example.json`).
- The settings tile is 112 × 112 px minimum (`settingsTileHeight`, `settingsTileMinWidth`; 2 × 56 as in master 23.10., decided by Johannes on 27.10.).
- Lane drag follows the accordion of `alfa-shell.js` grow() exactly (Johannes 16.10.); the least important lane yields first.
- Mail's left lane drags between 224 and 280 (`mailLaneMinimumLeft`, `mailLaneMaximumLeft`, passed as `AreaLimits` in `App/Mail/InboxLane.swift`); other areas have no maximum (MAIL-G01, Johannes 28.10.).
- Mail range (Johannes 29.10.): each mailbox loads a time range, set in its settings card under "Laden": 30 days (default), 90 days, 1 year or all. A pass per folder lists the ids of the range, drops stored mail the server no longer lists, fetches summaries only for unknown ids in chunks of 200 and refreshes flags of every known id (Gmail: history cursor read before the pass starts). "Ältere laden" (and the end of the list) extends a folder by 500 more ids. Search on submit runs on the server (every folder except spam and trash, or one query on Gmail) and pages per scope. Every choice is offered only when the transport can do it (`MirrorPort`, `EverywhereSearchPort`). Known limit: Gmail list rows come from `format=metadata`, so their attachment count is a guess (1 for any `multipart/mixed`, no names) until the message is opened. Open: a size limit in MB and storing attachments locally.
- Mailboxes (Johannes 28.10.): footer as card head (mock default), lacquer material, right stack and drafts kept per mailbox.
- `Resources/tokens.json` is converted from the `contract/` files of the delivery of 28.10. (base, theme-light, theme-dark, ground-lightGray); `constants` stay from code. Every delivered token is read by its view or has no counterpart in the app yet (lock screen, preview window, image tile, signature editor, service hero, glass and upward lacquer). Menus size to their longest entry on the 56 grid (`MenuWidthEngine`, 168 to 280).

## Sandbox (Claude Code)
- `swift build` and `xcodegen` do not run in the Claude sandbox; Johannes runs them in his own terminal.
- `utils/check_modules.sh` runs in the sandbox. If GRDB cannot be cloned, point `GRDB_SRC` at an existing GRDB checkout.
- Keychain and atomic-write tests show up as `sandbox-skipped` in the sandbox and pass on the Mac.

## Next tasks
1. Launch the app and check: legacy import (accounts, appearance, privacy carried over), Mail fetch and send, Settings, sign-in for Google and IMAP. Turn findings into tasks.
2. Check the CI on GitHub (`.github/workflows/check.yml`); fix it if it is red.
3. Launch the app and look at the assistant chat, the mailbox deck and Settings. Done from master 23.10. and the delivery of 28.10.: assistant chat, tokens (all wired into views), menu widths, `en` texts (211 keys matched from `contract/texts.json`), shell decisions F10/H01, MAIL-G01/P06/P07 and the mailbox deck (`App/Mail/AccountDeck.swift`) are in, none of it seen in the running app yet. Also in: list placeholder, fanned settings cards, tile row snap, toast and in-lane layers, "Angezeigt als" menu (stored in SettingsState). Also in: settings group title in the lane head, From name in the draft, "Angezeigt als" row in Settings. Still open for Johannes: own name for a main address in the draft From, the "Name in Mail" row (needs an editable inlet title), and the delivery's open points and questions (T5, T6, N15, N26 to N38; of N20 only save as template).
4. Small open points for Johannes to decide:
   - Wording of `text.settings.provider.other` ("Andere") and of `calc.seed.supplier`.
   - Mapping of 9 assistant tools onto existing privacy switches: time → Clockodo, documents/file → Drive, stock/cart/shipment → catalog, projects/sampling → studio knowledge, appointment → calendar.
   - Contact toasts in Settings still use `mail.toast.contact*` keys.
5. Bring the code back to its own rules (measured 29.10.): 169 of 686 files hold more than one main type; 12 files break the layering (`CompanyValues`, `ContactState`, `ChatState`, 10 assistant tools); `App` holds stores and clients besides views; 252 of 1197 text keys have no module source; forbidden words in 4 identifiers; `check.py` does not yet enforce several rules ARCHITECTURE.md describes. Each fix also makes the rule checked, then the rule's line here goes.
6. Projects and editors: wait for Johannes' mockups and the requirements spec of the old app, then port the archived logic file by file under English names.
7. Backlog, only on Johannes' word: wire up the left-out Mail actions and the internal assistant tools, each as its own task with its data source.
