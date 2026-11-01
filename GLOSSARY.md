# Glossary

One English term per concept. The German trade term is an alias. Terms that ALFA_OS already uses keep their code name.

## Knowledge structure

| Term | Definition | German alias |
|---|---|---|
| source | A document that a fact comes from. One record in `sources/`. | Quelle |
| atom | One checkable statement with source, stage, status and evidence. | Atom |
| library entry | One product or material with its technical data. | Bibliothekseintrag |
| rule | A formula that calculates part sizes. A function in `rules/`. | Regel |
| setup | Values for one workshop or one project. They override defaults. | Setup |
| stage | `design` or `production`. See AGENTS.md. | Stufe |
| evidence | How well a value is supported. See AGENTS.md. | Belegstufe |

## Cabinet

| Term | Definition | German alias | Code name |
|---|---|---|---|
| carcass | The box of a cabinet: sides, bottom, top or rails, back panel. | Korpus | `carcass` |
| base cabinet | A cabinet on the floor below the worktop. | Unterschrank | `base` |
| wall cabinet | A cabinet that hangs on the wall. | Oberschrank, Hängeschrank | `wall` |
| tall cabinet | A cabinet from the floor to near the ceiling. | Hochschrank | `tall` |
| housing | A tall cabinet for a built-in appliance. | Geräteschrank | `housing` |
| side panel | The left or right part of the carcass. | Seite | |
| back panel | The rear part of the carcass. | Rückwand | `back` |
| rail | A narrow horizontal part at the top of a base cabinet. | Traverse | |
| plinth | The part below the carcass that hides the feet. | Sockel | `plinth` |
| inside width | The clear width between the two side panels. Blum: LW. | lichte Weite | `inside_width_mm` |
| inside depth | The clear depth from the front edge to the back panel. Blum: LT. | lichte Tiefe | `inside_depth_mm` |
| hole row | The vertical row of holes for shelves and fittings, usually 32 mm apart. | Lochreihe | |
| front | The visible door, drawer front or flap. | Front | `front` |
| front execution | The material class of the front. | Frontausführung | `FrontExecution` in Calculation |
| front gap | The gap between two fronts or between a front and the carcass. | Fuge, Frontspalt | `gap` |

## Drawer

| Term | Definition | German alias | Blum abbreviation |
|---|---|---|---|
| drawer | A box that moves out on runners. | Schubkasten, Schublade | |
| inner drawer | A drawer behind a door or a front. | Innenschubkasten | |
| runner | The hardware that guides the drawer. | Führung, Auszug | |
| nominal length | The length class of a runner. | Nennlänge | NL |
| drawer inside width | The clear width inside a wooden drawer. | lichte Schubladenweite | SKW |
| drawer length | The length of a wooden drawer side. | Schubladenlänge | SKL |
| drawer side | The left or right part of a wooden drawer. | Zarge | |
| drawer side thickness | The thickness of a wooden drawer side. | Zargendicke | |
| depth requirement | The minimum inside depth of the carcass for a runner. | Platzbedarf | |
| front thickness | The thickness of the front. | Frontdicke | X |
| full extension | The drawer opens over its full length. | Vollauszug | |
| soft close | Damping that closes the drawer slowly. | Dämpfung | BLUMOTION |
| push to open | The drawer opens when a person pushes the front. | Push-to-open | TIP-ON |
