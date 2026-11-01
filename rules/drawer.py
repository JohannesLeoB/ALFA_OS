from dataclasses import dataclass
from typing import Dict, Optional, Tuple


@dataclass(frozen=True)
class Value:
    mm: float
    evidence: str
    sources: Tuple[str, ...]
    tolerance_mm: Optional[Tuple[float, float]] = None


@dataclass(frozen=True)
class Runner:
    key: str
    maker: str
    series: str
    model: str
    extension: str
    nominal_lengths_mm: Tuple[int, ...]
    side_thickness_mm: Tuple[Optional[float], Optional[float]]
    inside_width_deduction_mm: float
    length_deduction_mm: float
    depth_allowance_mm: float
    load_kg: Tuple[int, ...]
    sources: Tuple[str, ...]
    push_to_open: bool = False


RUNNERS: Dict[str, Runner] = {
    runner.key: runner
    for runner in (
        Runner("blum_tandem_560h", "Blum", "TANDEM", "560H", "full",
               (250, 270, 300, 320, 350, 380, 400, 420, 450, 480, 500, 520, 550, 600),
               (11, 16), 42, 10, 3, (30,), ("SRC-BLUM-005", "SRC-BLUM-009")),
        Runner("blum_tandem_550h", "Blum", "TANDEM", "550H", "partial",
               (270, 300, 350, 400, 450, 500, 550, 600, 650),
               (11, 16), 42, 10, 3, (30,), ("SRC-BLUM-005",)),
        Runner("blum_tandem_561h", "Blum", "TANDEM", "561H", "full",
               (260, 285, 310, 335, 360, 385, 410, 435, 460, 485, 510, 535, 560),
               (11, 16), 42, 10, 3, (30,), ("SRC-BLUM-005", "SRC-BLUM-009")),
        Runner("blum_tandem_560f", "Blum", "TANDEM", "560F", "full",
               (250, 270, 300, 350, 400, 450, 500, 550, 600),
               (17, 19), 49, 10, 3, (30,), ("SRC-BLUM-006", "SRC-STUDIO-001")),
        Runner("blum_movento_760h", "Blum", "MOVENTO", "760H", "full",
               (250, 270, 300, 320, 350, 380, 400, 420, 450, 480, 500, 520, 550, 600),
               (None, 16), 42, 10, 3, (40,), ("SRC-BLUM-010", "SRC-BLUM-011"), True),
        Runner("blum_movento_766h", "Blum", "MOVENTO", "766H", "full",
               (450, 500, 520, 550, 580, 600, 650, 700, 750),
               (None, 16), 42, 10, 3, (60, 70), ("SRC-BLUM-010", "SRC-BLUM-011"), True),
    )
}

DEPTH_EXTRAS_MM: Dict[str, Tuple[float, str, Tuple[str, ...]]] = {
    "runner_fixed_before_assembly": (1, "extracted", ("SRC-BLUM-010", "SRC-BLUM-011")),
    "side_stabilisation": (12, "extracted", ("SRC-BLUM-010", "SRC-BLUM-011")),
    "depth_adjustment": (3, "extracted", ("SRC-BLUM-010", "SRC-BLUM-011")),
    "posistop": (2, "extracted", ("SRC-BLUM-005", "SRC-BLUM-009")),
}

INNER_DRAWER_EXTRA_MM = {"soft_close": 3, "push_to_open": 7}

LEGRABOX_SIDE_HEIGHT_MM = {"N": 66.5, "M": 90.5, "K": 128.5, "C": 177.0, "F": 241.0}
LEGRABOX_WOOD_BACK_HEIGHT_MM = {"N": 39, "M": 63, "K": 101, "C": 148}
LEGRABOX_NOMINAL_LENGTHS_MM = {
    "N": (400, 450, 500, 550),
    "M": (270, 300, 350, 400, 450, 500, 550, 600, 650),
    "K": (300, 350, 400, 450, 500, 550, 600),
    "F": (400, 450, 500, 550, 600, 650),
}
LEGRABOX_SOURCES = ("SRC-BLUM-001", "SRC-BLUM-003", "SRC-BLUM-004")


def runner(key: str) -> Runner:
    if key not in RUNNERS:
        raise KeyError(f"unknown runner '{key}'")
    return RUNNERS[key]


def depth_requirement(key: str, nominal_length_mm: int, extras: Tuple[str, ...] = (),
                      inner_drawer_front_mm: Optional[float] = None, opening: str = "soft_close") -> Value:
    item = runner(key)
    if nominal_length_mm not in item.nominal_lengths_mm:
        raise ValueError(f"{key} has no nominal length {nominal_length_mm}")
    total = nominal_length_mm + item.depth_allowance_mm
    sources = list(item.sources)
    if inner_drawer_front_mm is not None:
        if opening not in INNER_DRAWER_EXTRA_MM:
            raise ValueError(f"unknown opening '{opening}'")
        total = nominal_length_mm + inner_drawer_front_mm + INNER_DRAWER_EXTRA_MM[opening]
    for name in extras:
        if name not in DEPTH_EXTRAS_MM:
            raise ValueError(f"unknown depth extra '{name}'")
        amount, _, extra_sources = DEPTH_EXTRAS_MM[name]
        total += amount
        sources.extend(s for s in extra_sources if s not in sources)
    return Value(total, "extracted", tuple(sources))


def select_nominal_length(key: str, inside_depth_mm: float, extras: Tuple[str, ...] = ()) -> Value:
    item = runner(key)
    fitting = [length for length in item.nominal_lengths_mm
               if depth_requirement(key, length, extras).mm <= inside_depth_mm]
    if not fitting:
        raise ValueError(f"{key} does not fit an inside depth of {inside_depth_mm} mm")
    return Value(max(fitting), "interpretation", item.sources)


def wooden_drawer(key: str, inside_width_mm: float, nominal_length_mm: int,
                  side_thickness_mm: float) -> Dict[str, Value]:
    item = runner(key)
    if nominal_length_mm not in item.nominal_lengths_mm:
        raise ValueError(f"{key} has no nominal length {nominal_length_mm}")
    low, high = item.side_thickness_mm
    if (low is not None and side_thickness_mm < low) or (high is not None and side_thickness_mm > high):
        raise ValueError(f"{key} takes drawer sides of {low} to {high} mm, not {side_thickness_mm} mm")
    inside = inside_width_mm - item.inside_width_deduction_mm
    return {
        "drawer_inside_width": Value(inside, "extracted", item.sources, (-1.5, 0.0)),
        "drawer_length": Value(nominal_length_mm - item.length_deduction_mm, "extracted", item.sources),
        "drawer_outside_width": Value(inside + 2 * side_thickness_mm, "interpretation", item.sources),
        "depth_requirement": depth_requirement(key, nominal_length_mm),
    }


def legrabox_parts(height: str, inside_width_mm: float, nominal_length_mm: int,
                   back: str = "wood") -> Dict[str, Value]:
    if height not in LEGRABOX_SIDE_HEIGHT_MM:
        raise ValueError(f"unknown LEGRABOX height '{height}'")
    lengths = LEGRABOX_NOMINAL_LENGTHS_MM.get(height)
    if lengths is not None and nominal_length_mm not in lengths:
        raise ValueError(f"LEGRABOX {height} has no nominal length {nominal_length_mm}")
    if back not in ("wood", "steel"):
        raise ValueError(f"unknown back '{back}'")
    parts = {
        "side_height": Value(LEGRABOX_SIDE_HEIGHT_MM[height], "extracted", LEGRABOX_SOURCES),
        "bottom_width": Value(inside_width_mm - 35, "derived", LEGRABOX_SOURCES),
        "bottom_length": Value(nominal_length_mm - (10 if back == "wood" else 21), "derived", LEGRABOX_SOURCES),
        "depth_requirement": Value(nominal_length_mm + 3, "extracted", LEGRABOX_SOURCES),
    }
    if back == "wood":
        parts["back_width"] = Value(inside_width_mm - 38, "derived", LEGRABOX_SOURCES)
        if height in LEGRABOX_WOOD_BACK_HEIGHT_MM:
            parts["back_height"] = Value(LEGRABOX_WOOD_BACK_HEIGHT_MM[height],
                                         "derived" if height == "N" else "extracted", LEGRABOX_SOURCES)
    return parts
