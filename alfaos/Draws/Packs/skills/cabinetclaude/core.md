# Cabinetclaude core

Kitchen knowledge for a joinery and interior designer at design stage. Values are ca.; real walls are crooked and a few mm do not matter. Sizes live here and in the files below, nowhere else.

## Start understanding

| Layer (Lage) | z from-to, mm | Note |
|---|---|---|
| Plinth (Sockel) | 0-80 | set back ca. 50 |
| Carcass (Korpus) | 80-880 | 800 high |
| Worktop (Arbeitsplatte) | 880-920 | 40, overhang ca. 20 |
| Niche (Nische) | 920-1520 | 600 to the wall units, 560 at least |
| Wall (Oberschrank) | 1520 up | 400-1000 high |
| Attic (Attika) | top of wall units to ceiling | closes the gap; no tool, state it |

- Studio practice in the person's own drawings: plinth 100, carcass 810, thin worktop 20, worktop top 930 (island ca. 910). Prefer it as start value when the person's style or input shows it; the table above is the fallback.

- Run (Zeile): cabinets side by side, left to right seen from the front. Layouts: single row, two rows, L, U, island (ca. 1200 clear to the other cabinets).
- 32 mm hole line (Lochreihe): joinery fact for shelf and fitting positions; it is not a width rule.
- Start values come from the person's presets; any size, split and arrangement is valid. Never refuse or round a size the person gave.
- Shared features (handle or grip strategy, front style, edge, plinth type) and shared materials (front, carcass, worktop) apply to all cabinets unless a cabinet overrides them.
- Fronts sit 18 thick in front of the carcass with a 2 gap; drawer and door fronts follow the split table.
- ca. honesty: take every size from the input, fill gaps from the start values, and list each filled value with its reason as an assumption.

## How to work

1. Read the input: room, walls, openings, wishes, appliances, sizes given. Note what is missing.
2. Choose the layout: run lengths from the room, sink and hob positions, work triangle, tall units at the run ends.
3. add_kitchen with the runs; sizes only where the person gave them or the room forces them.
4. Refine with free sizes: filler (Passstück) to close a run, odd widths, heights for lower ceilings.
5. render_preview, check, correct; then offer variants (see variants).
6. finish: assumptions as ca. values, what the tools cannot draw, open questions.

## Pointers

- Generator: tool add_kitchen builds carcass, plinth, worktop, fronts and the opening units. Tops sit on the cabinet before them; a run without origin joins after a corner cabinet.
- Editing: tool edit_cabinet changes one cabinet by id (resize, set, insert, duplicate, remove, move, flip hinge, split, type, override, reset to shared); the person uses the same edits on the canvas, so read get_state before you change their work.
- Notation: fronts read top to bottom, `left / low,mid,high@500 / oven`; see splits.
- Specs for the joiner: specs/cabinetclaude/ (korpus, fronten, geraete, system).
- Not drawn yet, so say so in finish: handles, lift-up and fold flaps, inner drawers, end panels (Wange), attic, hood body, downdraft duct.
