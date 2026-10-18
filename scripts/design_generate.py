#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import shutil
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MANIFEST = os.path.join(ROOT, "DESIGN", "MANIFEST.json")
UNPACK = os.path.join(ROOT, "dist", "master-latest")
SHEET = "TOKENBOGEN.json"
STAMP = os.path.join(ROOT, "gestaltung", "alfa-interface", "design.stamp.json")
OUTPUT = os.path.join(ROOT, "alfaos", "Kit", "Sources", "ShellCore", "DesignTokens.swift")
INDENT = "    "
KEYWORDS = {"default", "in", "is", "as", "if", "else", "for", "func", "let", "var", "class", "enum", "struct", "self",
            "super", "true", "false", "nil", "return", "where", "while", "case", "switch", "init", "internal", "private",
            "public", "static", "extension", "protocol", "operator", "subscript", "import", "repeat", "guard", "do"}
STAMP_FIELDS = ("delivery", "deliveredAt", "adoptedAt", "state", "zipSha256")
MODES = {"light": "light", "dark": "dark", "hell": "light", "dunkel": "dark"}


def ident(name):
    return "`%s`" % name if name in KEYWORDS else name


def cap(name):
    return name[0].upper() + name[1:]


def num(value):
    value = float(value)
    return repr(int(value)) + ".0" if value == int(value) else repr(value)


def is_leaf(node):
    return isinstance(node, dict) and "$value" in node


def children(node):
    return [(k, v) for k, v in node.items() if not k.startswith("$")]


def dimension(value):
    if isinstance(value, dict):
        return float(value["value"])
    return float(value)


def seconds(value):
    amount = float(value["value"])
    return amount / 1000.0 if value.get("unit") == "ms" else amount


def rgb(value):
    c = value["components"]
    return "RGB(%s, %s, %s, %s)" % (num(c[0]), num(c[1]), num(c[2]), num(value.get("alpha", 1)))


def resolve(source, ref):
    node = source
    for part in ref.strip("{}").split("."):
        if part not in node and MODES.get(part) in node:
            part = MODES[part]
        node = node[part]
    return node


def color_expr(source, value):
    if isinstance(value, str):
        return color_expr(source, resolve(source, value)["$value"])
    return rgb(value)


def shadow_expr(source, layers):
    out = []
    for layer in layers:
        out.append("ShadowLayer(inset: %s, x: %s, y: %s, blur: %s, spread: %s, color: %s)" % (
            "true" if layer["inset"] else "false", num(dimension(layer["offsetX"])), num(dimension(layer["offsetY"])),
            num(dimension(layer["blur"])), num(dimension(layer["spread"])), color_expr(source, layer["color"])))
    return "[" + ", ".join(out) + "]"


def scalar_block(title, node, render):
    lines = ["%spublic enum %s {" % (INDENT, title)]
    for key, leaf in children(node):
        if is_leaf(leaf):
            lines.append("%s%spublic static let %s = %s" % (INDENT, INDENT, ident(key), render(leaf)))
    lines.append("%s}" % INDENT)
    return lines


def number(value):
    if isinstance(value, dict):
        return num(dimension(value))
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return num(value)
    return None


def numeric_block(title, node, whole=False):
    lines = ["%spublic enum %s {" % (INDENT, title)]
    for key, leaf in children(node):
        if not is_leaf(leaf):
            continue
        text = str(int(leaf["$value"])) if whole else number(leaf["$value"])
        if text is not None:
            lines.append("%s%spublic static let %s = %s" % (INDENT, INDENT, ident(key), text))
    lines.append("%s}" % INDENT)
    return lines


def component_block(source, node):
    lines = ["%spublic enum Component {" % INDENT]
    for key, leaf in children(node):
        ref = leaf if isinstance(leaf, str) else leaf["$value"]
        target = ref.strip("{}").split(".")
        expr = "%s.%s" % (cap(target[0]), ".".join([ident(p) for p in target[1:]]))
        lines.append("%s%spublic static let %s = %s" % (INDENT, INDENT, ident(key), expr))
    lines.append("%s}" % INDENT)
    return lines


def colors_struct(source, node, name):
    keys = [k for k, v in children(node) if is_leaf(v)]
    lines = ["public struct %s: Sendable, Equatable {" % name]
    for key in keys:
        lines.append("%spublic let %s: RGB" % (INDENT, ident(key)))
    lines.append("}")
    return lines, keys


def colors_value(source, node, keys, name, fallback=None):
    items = []
    for key in keys:
        leaf = node.get(key) or (fallback or {}).get(key)
        items.append("%s: %s" % (ident(key), color_expr(source, leaf["$value"])))
    return "%s(%s)" % (name, ", ".join(items))


def shadows_struct(keys):
    lines = ["public struct DesignShadows: Sendable, Equatable {"]
    for key in keys:
        lines.append("%spublic let %s: [ShadowLayer]" % (INDENT, ident(key)))
    lines.append("}")
    return lines


def build(source_bytes, stamp):
    source = json.loads(source_bytes.decode("utf-8"))
    out = ["public enum Design {"]
    out += scalar_block("Size", source["size"], lambda l: num(dimension(l["$value"])))
    out += scalar_block("Spacing", source["spacing"], lambda l: num(dimension(l["$value"])))
    out += scalar_block("Radius", source["radius"], lambda l: num(dimension(l["$value"])))
    out += scalar_block("Duration", source["motion"]["duration"], lambda l: num(seconds(l["$value"])))
    out += scalar_block("Easing", source["motion"]["easing"], lambda l: "CubicBezier(x1: %s, y1: %s, x2: %s, y2: %s)" % tuple(num(v) for v in l["$value"]))
    out += scalar_block("TextSize", source["typography"]["size"], lambda l: num(dimension(l["$value"])))
    out += scalar_block("Weight", source["typography"]["weight"], lambda l: str(int(l["$value"])))
    out += scalar_block("LineHeight", source["typography"]["lineHeight"], lambda l: num(dimension(l["$value"])))
    out += numeric_block("Count", source["count"], whole=True)
    out += numeric_block("Opacity", source["opacity"])
    out += numeric_block("Confirm", source["confirm"])
    out += numeric_block("Motion", source["motion"])
    out += component_block(source, source["component"])
    out.append("}")
    light = source["color"]["light"]
    block, keys = colors_struct(source, light, "DesignColors")
    out += [""] + block
    out += ["", "public extension DesignColors {"]
    out.append("%sstatic let light = %s" % (INDENT, colors_value(source, light, keys, "DesignColors")))
    out.append("%sstatic let dark = %s" % (INDENT, colors_value(source, source["color"]["dark"], keys, "DesignColors")))
    out.append("%sstatic let lightGray = %s" % (INDENT, colors_value(source, source["color"]["lightGrayOverrides"], keys, "DesignColors", light)))
    out.append("}")
    shadow_keys = [k for k, v in children(source["shadow"]["light"]) if is_leaf(v) and k in source["shadow"]["dark"]]
    single = [(m, k) for m in ("light", "dark") for k, v in children(source["shadow"][m]) if is_leaf(v) and k not in source["shadow"]["dark" if m == "light" else "light"]]
    out += [""] + shadows_struct(shadow_keys)
    out += ["", "public extension DesignShadows {"]
    for mode in ("light", "dark"):
        items = ", ".join("%s: %s" % (ident(k), shadow_expr(source, source["shadow"][mode][k]["$value"])) for k in shadow_keys)
        out.append("%sstatic let %s = DesignShadows(%s)" % (INDENT, mode, items))
    for mode, key in single:
        out.append("%sstatic let %s%s: [ShadowLayer] = %s" % (INDENT, ident(key), cap(mode), shadow_expr(source, source["shadow"][mode][key]["$value"])))
    out.append("}")
    out += ["", "public struct DesignStackStep: Sendable, Equatable {", "%spublic let surface: RGB" % INDENT, "%spublic let ink: RGB" % INDENT, "}", "", "public extension Design {"]
    for mode in ("light", "dark"):
        steps = ", ".join("DesignStackStep(surface: %s, ink: %s)" % (rgb(s["surface"]["$value"]), rgb(s["ink"]["$value"])) for s in source["stack"][mode])
        out.append("%sstatic let stack%s: [DesignStackStep] = [%s]" % (INDENT, cap(mode), steps))
    out.append("}")
    out += surface_block(source)
    out += ["", "public enum DesignStamp {"]
    for field in STAMP_FIELDS + ("content",):
        out.append("%spublic static let %s = %s" % (INDENT, field, json.dumps(stamp[field], ensure_ascii=False)))
    out.append("}")
    return ("\n".join(out) + "\n").encode("utf-8")


def surface_block(source):
    surface = source["surface"]
    layers = {layer["name"]: layer for layer in surface["lacquer"]["layers"]}
    gloss, seam, cast = layers["topGloss"], layers["topSeam"], layers["castShadow"]
    items = [
        ("topGlossFrontLight", gloss["front"]["light"]), ("topGlossFrontDark", gloss["front"]["dark"]),
        ("topGlossBackLightCard", gloss["backLightCard"]), ("topGlossBackDarkCard", gloss["backDarkCard"]),
        ("topSeamFrontLight", seam["front"]["light"]), ("topSeamBackLight", seam["back"]["light"]), ("topSeamDark", seam["dark"]),
        ("castShadowLight", cast["light"]), ("castShadowDark", cast["dark"]),
        ("glassLight", surface["glass"]["light"]), ("glassDark", surface["glass"]["dark"]),
    ]
    out = ["", "public enum DesignSurface {"]
    for name, layer in items:
        out.append("%spublic static let %s: [ShadowLayer] = %s" % (INDENT, name, shadow_expr(source, layer)))
    out.append("}")
    return out


def read(path):
    with open(path, "rb") as handle:
        return handle.read()


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def latest_master():
    entries = json.loads(read(MANIFEST).decode("utf-8"))["masters"]
    latest = [e for e in entries if e.get("rank") == "latest"]
    if len(latest) != 1:
        raise ValueError("DESIGN/MANIFEST.json: expected exactly one master with rank latest")
    return latest[0]


def unpack(entry):
    path = os.path.join(ROOT, "DESIGN", entry["zip"])
    actual = sha256(read(path))
    if actual != entry["zipSha256"]:
        raise ValueError("checksum of %s is %s, manifest says %s: stop" % (entry["zip"], actual, entry["zipSha256"]))
    shutil.rmtree(UNPACK, ignore_errors=True)
    os.makedirs(UNPACK)
    root = os.path.realpath(UNPACK) + os.sep
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if not os.path.realpath(os.path.join(UNPACK, name)).startswith(root):
                raise ValueError("unsafe path in zip: %s" % name)
        archive.extractall(UNPACK)
    found = [os.path.join(d, SHEET) for d, _, files in os.walk(UNPACK) if SHEET in files]
    if len(found) != 1:
        raise ValueError("expected exactly one %s in %s" % (SHEET, entry["zip"]))
    return read(found[0])


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    try:
        entry = latest_master()
        source_bytes = unpack(entry)
        stamp = json.loads(read(STAMP).decode("utf-8"))
        for field in STAMP_FIELDS + ("content",):
            if not isinstance(stamp.get(field), str) or not stamp[field].strip():
                raise ValueError("design.stamp.json: %s is missing" % field)
        if stamp["zipSha256"] != entry["zipSha256"]:
            raise ValueError("design.stamp.json: zipSha256 is not the latest master: set it to %s and renew adoptedAt and state" % entry["zipSha256"])
        expected = sha256(source_bytes)
        if stamp["content"] != expected:
            raise ValueError("%s changed since its stamp: set content to %s and renew adoptedAt and state" % (SHEET, expected))
        data = build(source_bytes, stamp)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print("design_generate: %s" % error, file=sys.stderr)
        return 2
    if args.check:
        try:
            same = read(OUTPUT) == data
        except OSError:
            same = False
        print("design_generate: outputs match the source" if same else "design_generate: stale or missing DesignTokens.swift")
        return 0 if same else 1
    with open(OUTPUT, "wb") as handle:
        handle.write(data)
    print("wrote %s" % OUTPUT)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
