#!/usr/bin/env python3
"""Write the design contract (gestaltung/vertrag) from the canon (gestaltung/kanon).

Reads gestaltung/kanon/tokens.json (list form of the design system) and writes
  vertrag/tokens.json         light values, DTCG 2025.10
  vertrag/tokens.dunkel.json  only the leaves whose dark value differs, same paths
and updates the sha256 and fassung of these two files in gestaltung/MANIFEST.json.

Run:  python3 scripts/vertrag_aus_kanon.py
The output depends only on the canon, so a second run changes nothing.
Aliases such as {koralle} are resolved; the contract has no $ref.
"""
import argparse
import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FASSUNG = "kanon-1791548941-589d"
# The canon lists the steps s1 to s6 and s8 = 48. The decision of 2026-10-09 renames the 48 step to s7
# and adds s8 = 64. Both are applied here, so the canon stays unchanged.
SPACING_RENAME = {"s8": "s7"}
SPACING_ADDED = {"s8": "64px"}
FONT_FAMILY = {"display": "System Display", "text": "System Text", "mono": "Mono"}
HEX_COLOR = re.compile(r"#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})")
ALIAS = re.compile(r"\{([^{}]+)\}")
DIMENSION = re.compile(r"(-?[0-9]+(?:\.[0-9]+)?)px")
SHADOW_NUMBER = re.compile(r"-?[0-9]+(?:\.[0-9]+)?(?:px)?")


def plain(text):
    value = float(text)
    return int(value) if value == int(value) else value


def color_token(text):
    """Hex text (3, 6 or 8 digits) to a DTCG color token."""
    match = HEX_COLOR.fullmatch(text)
    if not match:
        raise ValueError("not a hex colour: %s" % text)
    digits = match.group(1).upper()
    if len(digits) == 3:
        digits = "".join(c * 2 for c in digits)
    channels = [int(digits[i:i + 2], 16) for i in (0, 2, 4)]
    alpha = int(digits[6:8], 16) if len(digits) == 8 else 255
    value = {
        "colorSpace": "srgb",
        "components": [round(c / 255, 4) for c in channels],
        "alpha": 1 if alpha == 255 else round(alpha / 255, 4),
        "hex": "#" + digits,
    }
    return {"$type": "color", "$value": value}


def dimension_token(text):
    match = DIMENSION.fullmatch(text)
    if not match:
        raise ValueError("not a pixel value: %s" % text)
    return {"$type": "dimension", "$value": {"value": plain(match.group(1)), "unit": "px"}}


def number_token(value):
    return {"$type": "number", "$value": plain(str(value))}


def shadow_layers(text):
    """'inset 0 1px 0 #ffffffd9, 0 8px 32px #0000001a' to layers with kind, offsets, blur and colour."""
    layers = []
    for part in text.split(","):
        words = part.split()
        kind = "aussen"
        if words and words[0] == "inset":
            kind = "innen"
            words = words[1:]
        numbers = [w for w in words if SHADOW_NUMBER.fullmatch(w)]
        colour = [w for w in words if w.startswith("#")]
        if len(numbers) != 3 or len(colour) != 1 or len(numbers) + len(colour) != len(words):
            raise ValueError("shadow layer not read: %s" % part.strip())
        x, y, blur = [plain(n.replace("px", "")) for n in numbers]
        layers.append((kind, x, y, blur, colour[0]))
    return layers


def paired(value):
    """A value is one text or an object with light and dark. Returns (light, dark)."""
    if isinstance(value, dict):
        return value["light"], value["dark"]
    return value, value


def add(leaves, path, light, dark):
    leaves.append((tuple(path), light, dark))


def collect(canon):
    """Flat list of (path, light token, dark token) in the order of the canon."""
    leaves = []
    colours = {}
    raw = {t["name"]: t["value"] for t in canon["color"]["tokens"]}

    def resolve(name):
        if name in colours:
            return colours[name]
        light, dark = paired(raw[name])
        if isinstance(light, str) and ALIAS.fullmatch(light):
            target = light[1:-1]
            colours[name] = resolve(target)
            return colours[name]
        colours[name] = (color_token(light), color_token(dark))
        return colours[name]

    for token in canon["color"]["tokens"]:
        light, dark = resolve(token["name"])
        add(leaves, ["color", token["name"]], light, dark)

    for token in canon["spacing"]["tokens"]:
        name = SPACING_RENAME.get(token["name"], token["name"])
        add(leaves, ["space", name], dimension_token(token["value"]), dimension_token(token["value"]))
    for name, value in SPACING_ADDED.items():
        add(leaves, ["space", name], dimension_token(value), dimension_token(value))

    for token in canon["radius"]["tokens"]:
        add(leaves, ["radius", token["name"]], dimension_token(token["value"]), dimension_token(token["value"]))

    for group in canon["type"]["groups"]:
        for style in group["styles"]:
            base = ["text", style["name"]]
            family = {"$type": "fontFamily", "$value": [FONT_FAMILY[group["family"]]]}
            add(leaves, base + ["familie"], family, family)
            size = dimension_token(style["fontSize"]) if style["fontSize"].endswith("px") else None
            add(leaves, base + ["groesse"], size, size)
            weight = {"$type": "fontWeight", "$value": int(style["fontWeight"])}
            add(leaves, base + ["gewicht"], weight, weight)
            line = number_token(style["lineHeight"])
            add(leaves, base + ["zeilenhoehe"], line, line)
            if "letterSpacing" in style:
                spacing = number_token(float(style["letterSpacing"].replace("em", "")))
                add(leaves, base + ["laufweite"], spacing, spacing)

    for token in canon["shadow"]["tokens"]:
        light_text, dark_text = paired(token["value"])
        light_layers = shadow_layers(light_text)
        dark_layers = shadow_layers(dark_text)
        for index, (kind, x, y, blur, colour) in enumerate(light_layers):
            d_kind, d_x, d_y, d_blur, d_colour = dark_layers[index]
            if d_kind != kind:
                raise ValueError("shadow layers differ in order: %s" % token["name"])
            base = ["shadow", token["name"], kind]
            add(leaves, base + ["versatzX"], dimension_token("%spx" % x), dimension_token("%spx" % d_x))
            add(leaves, base + ["versatzY"], dimension_token("%spx" % y), dimension_token("%spx" % d_y))
            add(leaves, base + ["unschaerfe"], dimension_token("%spx" % blur), dimension_token("%spx" % d_blur))
            add(leaves, base + ["farbe"], color_token(colour), color_token(d_colour))

    for token in canon["glas"]["tokens"]:
        value = token["value"]
        if value.endswith("px"):
            token_light = dimension_token(value)
        else:
            token_light = number_token(value)
        add(leaves, ["glas", token["name"]], token_light, token_light)

    return leaves


def nest(tree, path, token):
    node = tree
    for part in path[:-1]:
        node = node.setdefault(part, {})
    node[path[-1]] = token


def build(canon):
    light_tree, dark_tree = {}, {}
    for path, light, dark in collect(canon):
        nest(light_tree, path, light)
        if dark != light:
            nest(dark_tree, path, dark)
    return light_tree, dark_tree


def dump(tree):
    return json.dumps(tree, indent=2, ensure_ascii=True) + "\n"


def write(canon_dir, out_dir, manifest):
    with open(os.path.join(canon_dir, "tokens.json"), encoding="utf-8") as handle:
        canon = json.load(handle)
    light_tree, dark_tree = build(canon)
    os.makedirs(out_dir, exist_ok=True)
    written = {}
    for name, tree in (("tokens.json", light_tree), ("tokens.dunkel.json", dark_tree)):
        data = dump(tree).encode("utf-8")
        with open(os.path.join(out_dir, name), "wb") as handle:
            handle.write(data)
        written[name] = hashlib.sha256(data).hexdigest()
    if manifest:
        update_manifest(manifest, written)
    return written


def update_manifest(path, written):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    for entry in data["dateien"]:
        name = entry["pfad"].split("/")[-1]
        if entry["pfad"].startswith("vertrag/") and name in written:
            entry["sha256"] = written[name]
            entry["fassung"] = FASSUNG
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(data, indent=2, ensure_ascii=True) + "\n")


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--kanon", default=os.path.join(ROOT, "gestaltung", "kanon"))
    parser.add_argument("--target", default=os.path.join(ROOT, "gestaltung", "vertrag"))
    parser.add_argument("--manifest", default=os.path.join(ROOT, "gestaltung", "MANIFEST.json"),
                        help="empty string skips the manifest")
    args = parser.parse_args(argv)
    written = write(args.kanon, args.target, args.manifest or None)
    for name in sorted(written):
        print("%s  %s" % (written[name], os.path.join(args.target, name)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
