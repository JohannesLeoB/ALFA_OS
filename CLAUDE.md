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
- The assistant chat UI waits for its design; master 23.10. does not draw it (delivery item N37).
- On first launch `LegacyImportStore` (Sources/Hub/Store) imports the old Hub database and the old app settings once; the old data is never changed.
- The Airtable sale-price column name comes only from the company configuration (key `airtable.field.sale_price`, see `Resources/company.example.json`).
- The settings tile is 112 × 112 px minimum (`settingsTileHeight`, `settingsTileMinWidth`; 2 × 56 as in master 23.10., decided by Johannes on 27.10.).
- `Resources/tokens.json` is converted from the master's `contract/` files (base, theme-light, theme-dark, ground-lightGray); `constants` and the seven `size.menuWidth*` tokens stay from code until the menus use `menuMinWidth`, `menuMaxWidth` and `menuWidthStep`.

## Sandbox (Claude Code)
- `swift build` and `xcodegen` do not run in the Claude sandbox; Johannes runs them in his own terminal.
- `utils/check_modules.sh` runs in the sandbox. If GRDB cannot be cloned, point `GRDB_SRC` at an existing GRDB checkout.
- Keychain and atomic-write tests show up as `sandbox-skipped` in the sandbox and pass on the Mac.

## Next tasks
1. Launch the app and check: legacy import (accounts, appearance, privacy carried over), Mail fetch and send, Settings, sign-in for Google and IMAP. Turn findings into tasks.
2. Check the CI on GitHub (`.github/workflows/check.yml`); fix it if it is red.
3. Finish design master 23.10.: tokens are in; still open are the 427 texts with `de` and `en` from `contract/texts.json` (needs `en` in `utils/merge_strings.py`), menu widths on the 56 grid, and the delivery's open points and questions (T5, T6, N15, N20, N26 to N38, N43).
4. Small open points for Johannes to decide:
   - Wording of `text.settings.provider.other` ("Andere") and of `calc.seed.supplier`.
   - Mapping of 9 assistant tools onto existing privacy switches: time → Clockodo, documents/file → Drive, stock/cart/shipment → catalog, projects/sampling → studio knowledge, appointment → calendar.
   - Contact toasts in Settings still use `mail.toast.contact*` keys.
   - `utils/check.py` does not yet check "no dead public members" and "no module prefix" mechanically.
5. Backlog, only on Johannes' word: wire up the left-out Mail actions and the internal assistant tools, each as its own task with its data source.
