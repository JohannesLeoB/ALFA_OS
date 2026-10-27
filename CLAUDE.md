@AGENTS.md

# Session start

Binding: the rules in [AGENTS.md](AGENTS.md) (loaded above) and the schema in [ARCHITECTURE.md](ARCHITECTURE.md). Build, run and configuration: [README.md](README.md). This file holds status, decisions and the next tasks; whoever changes them updates it in the same commit.

## Status
- `main` is the rebuild from commit `34c7366` on: 14 modules plus app, schema-checked by `utils/check.py`.
- The old stand (legacy code, old docs, old agents and memory notes) is fully in tag `archive/before-rebuild`. Read with `git show archive/before-rebuild:<path>`.
- Verified on the Mac: `swift build`, `swift test` (343 tests, 0 failures), `utils/build_app.sh` (app in the dist folder).
- Not yet verified: launching the app and the first run with the one-time legacy import, the first CI run on GitHub.
- `main` on GitHub is protected. Johannes' account pushes past it as "Bypassed rule violations"; another account may be rejected. Then adjust the rule in the GitHub settings or work via a pull request.

## Decisions
- Work style: read every file before changing it; no blanket cuts or search-and-replace edits; ask before removing anything not proven dead. Old quotes in archived notes are not binding.
- Mail and Hub were rewritten without legacy code; integrations were adopted file by file.
- The Claude assistant (37 tools) and the calculation it drives are kept; calculation numbers and model routing stay unchanged.
- Finished but unwired parts stay `internal` and are not deleted: 9 assistant tools, the calculation learning path, DHL labels, the Clockodo time table.
- Mail menu entries and the format bar without a function are left out until they work.
- The assistant chat UI waits for the next design master (23.10.).
- On first launch `LegacyImportStore` (Sources/Hub/Store) imports the old Hub database and the old app settings once; the old data is never changed.
- The Airtable sale-price column name comes only from the company configuration (key `airtable.field.sale_price`, see `Resources/company.example.json`).

## Sandbox (Claude Code)
- `swift build` and `xcodegen` do not run in the Claude sandbox; Johannes runs them in his own terminal.
- `utils/check_modules.sh` runs in the sandbox. If GRDB cannot be cloned, point `GRDB_SRC` at an existing GRDB checkout.
- Keychain and atomic-write tests show up as `sandbox-skipped` in the sandbox and pass on the Mac.

## Next tasks
1. Launch the app and check: legacy import (accounts, appearance, privacy carried over), Mail fetch and send, Settings, sign-in for Google and IMAP. Turn findings into tasks.
2. Check the CI on GitHub (`.github/workflows/check.yml`); fix it if it is red.
3. Bring in design master 23.10.: update `Resources/tokens.json` from the master's TOKENBOGEN, run `python3 -I utils/generate_tokens.py`, review the diff, then build the assistant chat from the master.
4. Small open points for Johannes to decide:
   - Settings tile 96 px (TOKENBOGEN) vs. 84 px in the decision sheet of master 18.10.
   - Wording of `text.settings.provider.other` ("Andere") and of `calc.seed.supplier`.
   - Mapping of 9 assistant tools onto existing privacy switches: time → Clockodo, documents/file → Drive, stock/cart/shipment → catalog, projects/sampling → studio knowledge, appointment → calendar.
   - Contact toasts in Settings still use `mail.toast.contact*` keys.
   - `utils/check.py` does not yet check "no dead public members" and "no module prefix" mechanically.
5. Backlog, only on Johannes' word: wire up the left-out Mail actions and the internal assistant tools, each as its own task with its data source.
