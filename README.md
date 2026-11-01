# ALFA Knowledge: Kitchen and Joinery

This branch holds technical knowledge for kitchen and cabinet design and production.

It is preparatory work of the kitchen session for the Fusion kitchen skill. It collects sources, concepts and learning material. It does not set requirements for the ALFA_OS code. Johannes decides later who uses this knowledge and how.

This branch has no shared history with `main`. The rules of `main` (`AGENTS.md`, `utils/check.py`) do not apply here. The rules for this branch are in [AGENTS.md](AGENTS.md).

## Layers

| Layer | Folder | Content |
|---|---|---|
| Sources | `sources/` | One record per source document. Reference and locator only. No copies of documents. |
| Concepts | `concepts/` | One record per concept with English and German labels, synonyms, and the relations `broader` and `part_of`. |
| Atoms | `atoms/` | One checkable statement per line in English and German, with concepts, links, source, stage, status and evidence. |
| Media | `media/` | One record per image, drawing or page region, with its source and the concepts it shows. |
| Libraries | `libraries/` | One file per product or material entry: hardware, material, edge, appliance. |
| Rules | `rules/` | Formulas as Python functions, with tests. |
| Setups | `setups/` | Layers of values: default, company, workshop, user, project. A lower layer overrides only the values that it sets. |
| Skills | `skills/` | Packages for Claude. Not yet built. |

Record formats are in `schema/`. The table schema is in `sql/`. [GLOSSARY.md](GLOSSARY.md) explains the terms for people. The concepts in `concepts/` are the terms for machines.

## Commands

All commands use Python 3.9 or later and the standard library only.

```sh
python3 -I tools/validate.py
python3 -I -m unittest discover -s rules -p "test_*.py"
python3 -I tools/kb.py build
python3 -I tools/kb.py query "Schubkasten MOVENTO lichte Weite"
python3 -I tools/kb.py concept CON-RUNNER-MOVENTO
python3 -I tools/kb.py setup SET-STUDIO-EXAMPLE
python3 -I tools/build_xray.py
python3 -I tools/export_supabase.py
```

- `validate.py` checks every record against its schema. It checks that every source, concept, link target, parent setup and rule exists, and that IDs are unique.
- `kb.py build` writes `build/knowledge.sqlite` with full text search in English and German and one table of edges for all relations.
- `kb.py query` finds atoms in English or German. It also follows the concepts that match the words.
- `kb.py setup` shows the values of a setup after all parent layers are applied.
- `build_xray.py` writes `build/xray.html`. Do not edit the page by hand.
- `export_supabase.py` writes `build/supabase_seed.sql`. It leaves out library entries with `sharing: setup_only`.

## Supabase

Supabase is a mirror for online access. The files of this branch stay the source.

1. Create a project in an EU region.
2. Run `sql/schema.sql`, then `sql/postgres.sql`, in the SQL editor.
3. Run `python3 -I tools/export_supabase.py` and run `build/supabase_seed.sql` in the SQL editor.

The seed deletes and refills all tables. Do not edit data in Supabase.

## Status

The first scope is the standard base cabinet with drawers. The coordination strand for this work is `strands/S-kitchen-knowledge.md` in the repository `ALFA-Knowledge`.
