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
| Catalogues | `catalogs/` | One record per catalogue section: path of headings, printed and PDF pages, concepts. A map to read the right pages. No catalogue text. |
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
- `export_supabase.py` writes `build/supabase_schema.sql` and `build/supabase_seed.sql`. It leaves out library entries with `sharing: setup_only`.

## Catalogue text

The page text of a catalogue stays on the studio Mac in `creative claude/Training/05_Eingang_Quellen/verarbeitet/<catalogue>/pages.jsonl`. It is not in Git and not in Supabase, because the text belongs to the maker. Use `catalogs/` to find the pages, read them, and write atoms in your own words.

## Supabase

Supabase is a read mirror for agents and apps. The files of this branch stay the source.

- All tables are in the schema `kb`.
- `kb.search(query, max_rows)` searches atoms, concepts and catalogue sections in German and English.
- `kb.setup_resolved(setup)` returns the values of a setup after all parent layers.
- `kb.atom_cards` gives one row per atom with concepts, sources and links.
- Signed-in users can read. Only the service role writes. Library entries with `sharing: setup_only` are not exported.
- The columns `embedding` are empty. They are for semantic search later.

To fill or refresh the mirror:

1. Run `python3 -I tools/export_supabase.py`.
2. Apply `build/supabase_schema.sql` once as a migration.
3. Run `build/supabase_seed.sql`. The seed deletes and refills all tables.

Do not edit data in Supabase.

## Status

The first scope is the standard base cabinet with drawers. The coordination strand for this work is `strands/S-kitchen-knowledge.md` in the repository `ALFA-Knowledge`.
