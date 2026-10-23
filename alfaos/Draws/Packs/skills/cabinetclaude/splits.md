# Splits

Front notation, top to bottom, joined by ` / `: `left|right|pair` door, `n` or `low,mid,high` drawers, `oven|dishwasher|fridge|hob|sink` appliance, `open`, `glass`; `@h` fixes a height in mm. In add_kitchen write each term as one front object.

## Base

| Split | Notation | Typical | Drawing |
|---|---|---|---|
| Door | `left` | 300-450 | hinge side by the neighbour |
| Pair | `pair` | 800+, auto from 800 | two leaves, 2 centre gap |
| 1 + door | `1 / pair` | 800-900 | drawer on top, doors below |
| 2 drawers | `2` | 600-900 | low + high |
| 3 drawers | `low,low,high` | 600-900, pots | ca. quarter, quarter, half |
| 4 drawers | `4` | 600, cutlery to pots | smallest at least 100 |
| Inner drawers | `left` | 450-600 | draw the door; inner drawers are an assumption |
| Sink base | `left` or `pair` | 600-900 | door, ca. U-shaped drawer inside (assumption), sink inlay in the worktop |

## Wall

| Split | Notation | Typical | Drawing |
|---|---|---|---|
| Door | `left` | 300-600 | hinge by the neighbour |
| Pair | `pair` | 800 | two leaves |
| Lift-up, fold flap | `left` | above hob or sink | draw a door, state the flap as an assumption |
| Open | `open` | next to a window or end | hollow carcass, shelves ca. every 300 |
| Glass | `glass` | display wall unit | glass door in a frame |

## Tall

| Split | Notation | Typical | Drawing |
|---|---|---|---|
| Door | `pair` | 600 pantry (Vorrat) | full-height doors |
| Oven in the middle | `left / oven / left@770` | bottom edge of the oven ca. 850-900 | oven ca. 600 high, bottom door sets the height |
| Fridge + top | `fridge` + kind top | 600 housing | niche see appliances, top cabinet above |
| Pantry pull-out | `1` or `left` | 300-600 | one full-height drawer-like front, state it |
| Broom cupboard (Besenschrank) | `left` | 400-600 | one door, tall |

- Fixed heights come first, the rest is shared by the other fronts; fixed heights above the cabinet height fail with a split error.
- Default: prefer fewer, larger fronts and matching drawer lines across neighbouring bases; change when the person asks.
