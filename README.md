# ALFA Knowledge: Kitchen and Joinery

This branch holds technical knowledge for kitchen and cabinet design and production. It is the single source for these consumers:

- ALFA_OS Draws (design stage, approximate values).
- ALFA_OS Calculation (counts and types only, never prices).
- The Fusion kitchen skill and Claude agents (production stage, exact values).

This branch has no shared history with `main`. The rules of `main` (`AGENTS.md`, `utils/check.py`) do not apply here. The rules for this branch are in [AGENTS.md](AGENTS.md).

## Layers

| Layer | Folder | Content |
|---|---|---|
| 1 Sources | `sources/` | One record per source document. Reference and locator only. No copies of documents. |
| 2 Atoms | `atoms/` | One checkable statement per line, with source, stage, status and evidence. |
| 3 Libraries | `libraries/` | One file per product or material entry: hardware, material, edge, appliance. |
| 4 Rules | `rules/` | Formulas as Python functions, with tests. |
| 5 Setups | `setups/` | Values for one workshop or one project. They override defaults. |
| 6 Skills | `skills/` | Generated packages for Claude. Not yet built. |

Terms are in [GLOSSARY.md](GLOSSARY.md). Record formats are in `schema/`.

## Commands

All commands use Python 3.9 or later and the standard library only.

```sh
python3 -I tools/validate.py
python3 -I -m unittest discover -s rules -p "test_*.py"
```

`validate.py` checks every record against its schema, checks that each source reference exists, and checks that IDs are unique. It ends with exit code 0 when all checks pass.

## Status

The first scope is the standard base cabinet with drawers. The drawer rules for Blum TANDEM, MOVENTO and LEGRABOX are in `rules/drawer.py`. The coordination strand for this work is `straenge/kuechenwissen.md` in the repository `ALFA-Knowledge`.
