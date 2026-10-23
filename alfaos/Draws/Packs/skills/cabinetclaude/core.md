# Cabinetclaude core

Kitchen knowledge for a joinery and interior designer at design stage. Values are ca.; real walls are crooked and a few mm do not matter. Sizes live here and in the files below, nowhere else.

## Standard understanding

| Layer (Lage) | z from-to, mm | Note |
|---|---|---|
| Plinth (Sockel) | 0-80 | set back ca. 50 |
| Carcass (Korpus) | 80-880 | 800 high |
| Worktop (Arbeitsplatte) | 880-920 | 40, overhang ca. 20 |
| Niche (Nische) | 920-1520 | 600 to the wall units, 560 at least |
| Wall (Oberschrank) | 1520 up | 400-1000 high |
| Attic (Attika) | top of wall units to ceiling | closes the gap; no tool, state it |

- Studio practice in the person's own drawings: plinth 100, carcass 810, thin worktop 20, worktop top 930 (island ca. 910). Prefer it when the person's style or input shows it; the modular table above is the fallback.

- Run (Zeile): cabinets side by side, left to right seen from the front. Layouts: single row, two rows, L, U, island (ca. 1200 clear to the other cabinets).
- 32 mm hole grid (Lochraster): interiors and shelf positions follow it; it is not a width.
- Grid widths 200 300 400 600 800 are defaults for omitted sizes. Any positive size is valid: never refuse or round a size the person gave.
- Fronts sit 18 thick in front of the carcass with a 2 gap; drawer and door fronts follow the split table.
- ca. honesty: take every size from the input, fill gaps from the grid, and list each filled value with its reason as an assumption.

## How to work

1. Read the input: room, walls, openings, wishes, appliances, sizes given. Note what is missing.
2. Choose the layout: run lengths from the room, sink and hob positions, work triangle, tall units at the run ends.
3. add_kitchen with the runs; sizes only where the person gave them or the room forces them.
4. Refine with free sizes: filler (Passstück) to close a run, odd widths, heights for lower ceilings.
5. render_preview, check, correct; then offer variants (see variants).
6. finish: assumptions as ca. values, what the tools cannot draw, open questions.

## Pointers

- Generator: tool add_kitchen builds carcass, plinth, worktop, fronts and the opening units. Tops sit on the cabinet before them; a run without origin joins after a corner cabinet.
- Notation: fronts read top to bottom, `left / low,mid,high@500 / oven`; see splits.
- Specs for the joiner: specs/cabinetclaude/ (korpus, fronten, geraete, system).
- Not drawn yet, so say so in finish: handles, lift-up and fold flaps, inner drawers, end panels (Wange), attic, hood body, downdraft duct.
