# Variants

Offer variants A, B and C when the client has not decided, or when asked.

## Method

1. Build the brief version first and keep it as A.
2. Change exactly one axis per variant; never two at once.
3. Keep the room, the work triangle (sink, hob, fridge) and the clearances.
4. Rebuild with add_kitchen under the same prefix (it replaces the earlier kitchen), render_preview, then the next variant.
5. Name each variant in one line in finish: `B: handleless, rest as A`.

## Axes

| Axis | Examples |
|---|---|
| Layout | single row, L, U, island; tall units at one end or both |
| Front split | drawers instead of doors, 3 drawers instead of 2, tall oven or base oven |
| Handle strategy | handle (Griff), handleless channel (Griffleiste), push-to-open; not drawn yet, state it |
| Material | front, carcass, worktop through frontMaterial, material and the catalogue slots |
| Appliance placement | oven in the tall unit or under the hob, dishwasher left or right of the sink |

- Material variants use the variants of the project (role to code); other axes use add_kitchen.
- A variant that breaks the triangle or a clearance is not a variant: fix it or drop it.
- Mark which variant you recommend and why in one sentence.
