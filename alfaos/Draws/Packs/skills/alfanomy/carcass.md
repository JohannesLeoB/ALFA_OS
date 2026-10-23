# Carcass grid

Common modular kitchen sizes. Use them to fill gaps when the input gives no size, and record each as an assumption. Sizes are carcass sizes in mm without fronts unless noted.

- Base cabinet: height 800 on plinth or legs 80, worktop 40, so worktop height 920. Depth 600, shallow 370. Widths 200, 300, 400, 600, 800.
- Sink, hob and oven base: 600 or 800 wide, 600 deep.
- Corner base: 1280 × 680 (blind corner) or 880 × 880 (L corner), 800 high.
- Wall cabinet: depth 370. Heights 400, 600, 800, 1000. Widths 200, 300, 400, 600, 800. Hood cabinet 600 or 800 wide.
- Corner wall cabinet: 675 × 675, heights 600, 800, 1000.
- Gap worktop to wall cabinet: at least 560, usually 600.
- Tall cabinet: heights 1400, 2000, 2200 on plinth 80. Depth 600, shallow 370. Widths 400, 600, 800. Fridge and oven housings 600 × 600, ventilated.
- Top cabinet over a tall cabinet or fridge: 400 or 600 high, 600 deep, 400 or 600 wide.
- Open shelf units: 200 wide, 370 deep, heights 400, 600, 800.
- Fronts sit in front of the carcass, 18 thick with a 2 gap; drawer fronts split a base front in low, mid and high drawers.
- Layouts: single row, two rows, L, U, island; keep about 1200 between an island and the other cabinets.
- Prefer add_kitchen for cabinets: describe runs of cabinets with kind, fronts and the sizes the person gave; the generator builds carcasses, plinth, worktop, fronts and the units that open. Use add_parts only for special pieces.
- Widths, heights and depths are free: any positive size is valid. The grid above only fills a size that is omitted; never refuse or round a size the person gave.
- Fronts list from top to bottom: door (side left, right or pair), drawers (drawers like low, mid, high, or count), appliance (oven, dishwasher, fridge, hob, sink), open, glass. A run after a corner cabinet joins it when it has no origin.
