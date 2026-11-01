# Catalogue ingestion worker brief

You turn catalogue pages into structured training records. Work page by page. Do not skip pages.

## Input per page

- Text: `python3 -I /tmp/claude-0/-home-claude/052db9ab-e29a-5383-aaf9-1ab3ac8c8f37/scratchpad/ingest/page.py <catalog> <pdf_page>` prints the full page text and a line `#### MACHINE META` (article numbers, references, packaging lines found by regex).
- Image: `/mnt/user-data/uploads/creative claude/Training/05_Eingang_Quellen/verarbeitet/<catalog>/png/` — Haefele files are `p-0052.png` (4 digits), Blum files are `p-422.png` (3 digits). Open every page image with the Read tool. Drawings, tables and symbols are only correct on the image.
- Read the full text and the full image of each page. No skimming.

## Reading mode

Read like a person who browses a good catalogue with interest. Do not hunt only for listed fields.

- Ask on every part: what problem does it solve, what does it make possible, what is clever or unusual about it, where is it hard to use.
- Follow every cross reference (`►MB x.y`, "see page", accessory arrows) at least by name, and write a `relation` record. If the target page is in your batch, read it in context.
- Look for patterns across rows of a table (for example a dimension that is always half the board thickness) and write them as `context` records with `"derived": true`.
- Write a `discovery` record (`why_en`, `why_de`) for each smart, special or tricky solution, and for each idea it gives for design or production.

## Output

Append one JSON object per line to your output file. One record = one fact unit (atomic). Write English for `*_en` fields and German for `*_de` fields, in your own words. Never copy catalogue sentences. Short names, article numbers, numbers and units are facts and may be copied.

Common fields on every record:

- `id`: `REC-<CATCODE>-<pdf_page 4 digits>-<nn>` (CATCODE `HAEF26` or `BLUM27`)
- `record_type`: one of `product`, `article`, `mounting`, `drawing`, `relation`, `context`, `price`, `discovery`, `open`
- `source`: `SRC-HAEFELE-001` or `SRC-BLUM-015`; `pdf_page` (int); `printed_page` (string, Haefele label like `2.12`, Blum printed number)
- `section`: heading path as printed on the page (list of strings)
- `product`: id of the product record this record belongs to (not on product records)
- `extracted_at`: UTC timestamp from `date -u +%Y-%m-%dT%H:%M:%SZ`, taken when you write the record
- `evidence`: `verified` if you read the value on the page image, `extracted` if only from the text
- `confidence`: 0.0 to 1.0

Record types:

- `product`: maker, brand, series, `name` (catalogue name), `universal_class_en` and `universal_class_de` (maker-neutral class, for example "cam connector for 16-19 mm boards" / "Exzenterverbinder für 16-19 mm Platten"), `function_en/_de`, `materials`, `finishes`, `application` (board thickness range in mm, board types, door or drawer type), `requirements` (bore diameter and depth in mm, distances, hole row), `loads` (kg, N), `standards`, `concepts` (CON- ids from the list below, or `proposed_concepts` as English labels).
- `article`: `article_no` (exact), `variant` (object of normalized attributes: lengths in mm, weights in kg, angles in deg, finish, colour, thread), `packaging_unit` (number), `packaging_text`, `set_contents`, `min_order_qty`, `availability_note`, `delivery_note`.
- `mounting`: one step or one hint: `step_en/_de`, `tools`, `bore_diameter_mm`, `bore_depth_mm`, `distances_mm` (object), `screws`, `order`.
- `drawing`: `kind` (section, plan, elevation, drilling_pattern, exploded, diagram), `shows_en`, `dimensions` (object label -> value in mm with the label used in the drawing), `figure_region` (top, middle, bottom, left, right).
- `relation`: `rel` (`accessory_of`, `requires`, `alternative_to`, `replaces`, `same_as`, `see_page`), `from`, `to` (article numbers, product ids or page labels).
- `context`: page-level facts: notes, warnings, symbols and their meaning, abbreviations, test values, application limits.
- `price`: only if a price is printed: `article_no`, `amount`, `currency`, `vat_included` (true/false/null if unclear), `price_unit` (piece, set, pair, m, pack), `per_quantity`, `quantity_breaks`, `valid_note`. If the page has no price, write no price record.
- `open`: something you could not read or resolve, with `question_en`.

Rules:

- Units: mm, kg, N, deg. Convert cm and m. Decimal point, not comma.
- Anonymous: no names of people, customers or projects. Maker and brand names are fine.
- Keep article numbers exactly as printed (dots, letters).
- One article number = one `article` record, even in long tables.
- If text and image disagree, trust the image and say so in `note`.

Concept ids you may use: CON-HINGE CON-MOUNTING-PLATE CON-HINGE-CUP CON-CUP-DISTANCE CON-CUP-OVERLAY CON-FRONT-OVERLAY CON-OVERLAY-TYPE CON-HINGE-CRANK CON-OPENING-ANGLE CON-MIN-GAP CON-FRONT CON-FRONT-GAP CON-FRONT-HEIGHT CON-FRONT-WIDTH CON-FRONT-THICKNESS CON-FRONT-WEIGHT CON-SIDE-WALL-THICKNESS CON-CARCASS CON-CARCASS-WIDTH CON-SIDE-PANEL CON-BOTTOM-PANEL CON-RAIL CON-BACK-PANEL CON-SHELF CON-SHELF-SUPPORT CON-HOLE-ROW CON-CONNECTOR CON-GROOVE CON-PLINTH CON-PLINTH-FOOT CON-CABINET-HANGER CON-WORKTOP CON-DRAWER CON-INNER-DRAWER CON-DRAWER-SIDE CON-DRAWER-BOTTOM CON-DRAWER-INSIDE-WIDTH CON-DRAWER-LENGTH CON-RUNNER CON-RUNNER-TANDEM CON-RUNNER-MOVENTO CON-BOX-LEGRABOX CON-NOMINAL-LENGTH CON-DEPTH-REQUIREMENT CON-INSIDE-WIDTH CON-INSIDE-DEPTH CON-SIDE-STABILISATION CON-SOFT-CLOSE CON-PUSH-TO-OPEN CON-EXTENSION CON-TOLERANCE-COMPENSATION CON-CUTLERY-INSERT CON-LIFT-SYSTEM CON-POCKET-SYSTEM CON-SLIDING-DOOR CON-HANDLE CON-HANDLE-PROFILE CON-CHIPBOARD CON-MDF CON-MULTIPLEX CON-BOARD-THICKNESS

## Status

After each page, append one line to your status file:
`{"catalog": "...", "pdf_page": N, "stage": "worker_read", "at": "<UTC timestamp>", "records": <count>, "worker": "<your batch name>"}`

## Finish

When all pages are done, reply with: pages done, records per type, article numbers found versus the machine meta list (count of numbers in meta that you did not record, and why), open questions. Keep the reply short.
