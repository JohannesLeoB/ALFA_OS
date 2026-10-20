#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
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


def hex_rgb(text):
    h = text.lstrip("#")
    parts = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return "RGB(%s, %s, %s, 1.0)" % tuple(num(round(p, 4)) for p in parts)


def mood_block(node):
    keys = [k for k, v in children(node) if is_leaf(v)]
    out = ["", "public struct DesignMoods: Sendable, Equatable {"]
    for key in keys:
        out.append("%spublic let %s: RGB" % (INDENT, ident(key)))
    out += ["}", "", "public extension DesignMoods {"]
    for mode in ("light", "dark"):
        items = ", ".join("%s: %s" % (ident(k), hex_rgb(node[k]["$value"][mode])) for k in keys)
        out.append("%sstatic let %s = DesignMoods(%s)" % (INDENT, mode, items))
    out.append("}")
    return out


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
    out += scalar_block("Family", source["typography"]["family"], lambda l: json.dumps(l["$value"]))
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
    out += mood_block(source["color"]["mood"])
    shadow_keys =[k for k, v in children(source["shadow"]["light"]) if is_leaf(v) and k in source["shadow"]["dark"]]
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


def contract_prefix(names):
    """Return the folder prefix of contract/ in a list of ZIP names, or None.
    Allowed places: the ZIP root, or the one wrapper folder that holds everything."""
    tops = {n.split("/", 1)[0] for n in names if n.strip("/")}
    roots = [""]
    if len(tops) == 1 and any("/" in n.strip("/") for n in names):
        roots.append(tops.copy().pop() + "/")
    found = [r + "contract/" for r in roots if any(n.startswith(r + "contract/") and not n.endswith("/") for n in names)]
    if len(found) > 1:
        raise ValueError("more than one contract/ folder in the master: %s" % ", ".join(found))
    return found[0] if found else None


def contract_content(files):
    """Hash of a contract: SHA-256 of the sorted lines '<sha256>  <relative path>' of its files."""
    lines = "".join("%s  %s\n" % (sha256(files[name]), name) for name in sorted(files))
    return sha256(lines.encode("utf-8"))


CONTRACT_REF = re.compile(r"^#/(sets|modifiers)/([A-Za-z0-9_-]+)$")
ALIAS = re.compile(r"^\{([A-Za-z0-9]+(?:\.[A-Za-z0-9]+)*)\}$")
NO_ENUM_NAME = {"Type", "Self", "Protocol"}


def contract_json(files, name):
    if name not in files:
        raise ValueError("contract/%s is missing" % name)
    try:
        return json.loads(files[name].decode("utf-8"))
    except ValueError as error:
        raise ValueError("contract/%s: not valid JSON (%s)" % (name, error))


def contract_themes(files):
    """Read alfa.resolver.json. Return {theme: [token file names in resolution order]}."""
    resolver = contract_json(files, "alfa.resolver.json")
    modifiers = [m for m in (CONTRACT_REF.match(step.get("$ref", "")) for step in resolver["resolutionOrder"]) if m and m.group(1) == "modifiers"]
    if len(modifiers) != 1:
        raise ValueError("alfa.resolver.json: expected exactly one modifier in resolutionOrder, found %d" % len(modifiers))
    themes = list(resolver["modifiers"][modifiers[0].group(2)]["contexts"])
    out = {}
    for theme in themes:
        order = []
        for step in resolver["resolutionOrder"]:
            match = CONTRACT_REF.match(step.get("$ref", ""))
            if not match:
                raise ValueError("alfa.resolver.json: unknown resolutionOrder ref %r" % step.get("$ref"))
            if match.group(1) == "sets":
                order += [r["$ref"] for r in resolver["sets"][match.group(2)]["sources"]]
            else:
                order += [r["$ref"] for r in resolver["modifiers"][match.group(2)]["contexts"][theme]]
        out[theme] = order
    return out


def merge_tree(base, over):
    out = dict(base)
    for key, value in over.items():
        left = out.get(key)
        if isinstance(left, dict) and isinstance(value, dict) and "$value" not in left and "$value" not in value:
            out[key] = merge_tree(left, value)
        else:
            out[key] = value
    return out


def flat_tokens(node, prefix="", group_type=None, out=None):
    """Return {dotted path: (type, value)} for all tokens of a merged tree."""
    out = {} if out is None else out
    for key, sub in node.items():
        if key.startswith("$") or not isinstance(sub, dict):
            continue
        path = prefix + "." + key if prefix else key
        if "$value" in sub:
            kind = sub.get("$type", group_type)
            if kind is None:
                raise ValueError("%s: token has no $type" % path)
            out[path] = (kind, sub["$value"])
        else:
            flat_tokens(sub, path, sub.get("$type", group_type), out)
    return out


class Resolver:
    """Resolve aliases of one theme. A type without mapping is an error with its path."""

    def __init__(self, tokens):
        self.tokens = tokens

    def token(self, path, stack=()):
        if path in stack:
            raise ValueError("%s: alias cycle %s" % (path, " -> ".join(stack + (path,))))
        kind, value = self.tokens[path]
        return self.value(kind, value, path, stack + (path,))

    def alias(self, kind, text, path, stack):
        target = ALIAS.match(text).group(1)
        if target not in self.tokens:
            raise ValueError("%s: alias %s does not resolve" % (path, text))
        if self.tokens[target][0] != kind:
            raise ValueError("%s: alias %s has type %s, expected %s" % (path, text, self.tokens[target][0], kind))
        return self.token(target, stack)

    def value(self, kind, value, path, stack):
        if isinstance(value, str) and ALIAS.match(value):
            return self.alias(kind, value, path, stack)
        if kind == "color":
            if not isinstance(value, dict) or value.get("colorSpace") != "srgb" or len(value.get("components", [])) != 3:
                raise ValueError("%s: color must be srgb with three components" % path)
            return value
        if kind in ("dimension", "duration"):
            unit = "px" if kind == "dimension" else "ms"
            if not isinstance(value, dict) or value.get("unit") != unit or not isinstance(value.get("value"), (int, float)):
                raise ValueError("%s: %s must be {value, unit %s}" % (path, kind, unit))
            return value
        if kind == "cubicBezier":
            if not isinstance(value, list) or len(value) != 4:
                raise ValueError("%s: cubicBezier must hold four numbers" % path)
            return value
        if kind in ("number", "fontWeight"):
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                raise ValueError("%s: %s must be a number" % (path, kind))
            return value
        if kind == "fontFamily":
            if not (isinstance(value, str) or (isinstance(value, list) and value and all(isinstance(v, str) for v in value))):
                raise ValueError("%s: fontFamily must be a string or a list of strings" % path)
            return value
        if kind == "shadow":
            layers = []
            for layer in value if isinstance(value, list) else [value]:
                if isinstance(layer, str) and ALIAS.match(layer):
                    layers += self.alias("shadow", layer, path, stack)
                    continue
                if not isinstance(layer, dict):
                    raise ValueError("%s: shadow layer must be an object or an alias" % path)
                layers.append({
                    "inset": bool(layer.get("inset", False)),
                    "offsetX": self.value("dimension", layer["offsetX"], path + ".offsetX", stack),
                    "offsetY": self.value("dimension", layer["offsetY"], path + ".offsetY", stack),
                    "blur": self.value("dimension", layer["blur"], path + ".blur", stack),
                    "spread": self.value("dimension", layer["spread"], path + ".spread", stack),
                    "color": self.value("color", layer["color"], path + ".color", stack)})
            return layers
        if kind == "transition":
            if not isinstance(value, dict):
                raise ValueError("%s: transition must be an object" % path)
            return {"duration": self.value("duration", value["duration"], path + ".duration", stack),
                    "delay": self.value("duration", value["delay"], path + ".delay", stack),
                    "timingFunction": self.value("cubicBezier", value["timingFunction"], path + ".timingFunction", stack)}
        raise ValueError("%s: token type %s has no mapping in the generator" % (path, kind))


def contract_expr(kind, value):
    if kind == "color":
        return rgb(value)
    if kind == "dimension":
        return num(dimension(value))
    if kind == "duration":
        return num(seconds(value))
    if kind == "cubicBezier":
        return "CubicBezier(x1: %s, y1: %s, x2: %s, y2: %s)" % tuple(num(v) for v in value)
    if kind == "number":
        return num(value)
    if kind == "fontWeight":
        return str(int(value))
    if kind == "fontFamily":
        return json.dumps(value, ensure_ascii=False)
    if kind == "shadow":
        return shadow_expr(None, value)
    return "DesignTransition(duration: %s, delay: %s, timing: %s)" % (
        contract_expr("duration", value["duration"]), contract_expr("duration", value["delay"]),
        contract_expr("cubicBezier", value["timingFunction"]))


def contract_group(node, resolver, prefix, depth):
    lines = []
    pad = INDENT * depth
    for key, sub in node.items():
        if key.startswith("$") or not isinstance(sub, dict):
            continue
        path = prefix + "." + key if prefix else key
        if "$value" in sub:
            kind = resolver.tokens[path][0]
            lines.append("%spublic static let %s = %s" % (pad, ident(key), contract_expr(kind, resolver.token(path))))
        else:
            if cap(key) in NO_ENUM_NAME:
                raise ValueError("%s: group name %s cannot be a Swift type name" % (path, cap(key)))
            lines.append("%spublic enum %s {" % (pad, cap(key)))
            lines += contract_group(sub, resolver, path, depth + 1)
            lines.append("%s}" % pad)
    return lines


def build_contract(files, stamp):
    """Generate Swift from a contract folder: base and theme merged as alfa.resolver.json orders them."""
    out = ["public struct DesignTransition: Sendable, Equatable {", "%spublic let duration: Double" % INDENT,
           "%spublic let delay: Double" % INDENT, "%spublic let timing: CubicBezier" % INDENT, "}", "", "public enum DesignContract {"]
    for theme, order in contract_themes(files).items():
        tree = {}
        for name in order:
            tree = merge_tree(tree, contract_json(files, name))
        resolver = Resolver(flat_tokens(tree))
        out.append("%spublic enum %s {" % (INDENT, cap(theme)))
        out += contract_group(tree, resolver, "", 2)
        out.append("%s}" % INDENT)
    out.append("}")
    out += ["", "public enum DesignStamp {"]
    for field in STAMP_FIELDS + ("content",):
        out.append("%spublic static let %s = %s" % (INDENT, field, json.dumps(stamp[field], ensure_ascii=False)))
    out.append("}")
    return ("\n".join(out) + "\n").encode("utf-8")


def read_master(entry):
    """Check the ZIP against the manifest, unpack it in dist/ and return (kind, payload, content hash).
    kind is 'contract' (payload: {relative path: bytes}) when the master has contract/, else 'sheet' (payload: bytes)."""
    path = os.path.join(ROOT, "DESIGN", entry["zip"])
    actual = sha256(read(path))
    if actual != entry["zipSha256"]:
        raise ValueError("checksum of %s is %s, manifest says %s: stop" % (entry["zip"], actual, entry["zipSha256"]))
    shutil.rmtree(UNPACK, ignore_errors=True)
    os.makedirs(UNPACK)
    root = os.path.realpath(UNPACK) + os.sep
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        for name in names:
            if not os.path.realpath(os.path.join(UNPACK, name)).startswith(root):
                raise ValueError("unsafe path in zip: %s" % name)
        archive.extractall(UNPACK)
        prefix = contract_prefix(names)
        if prefix:
            files = {n[len(prefix):]: archive.read(n) for n in names if n.startswith(prefix) and not n.endswith("/")}
            return "contract", files, contract_content(files)
    found = [os.path.join(d, SHEET) for d, _, files in os.walk(UNPACK) if SHEET in files]
    if len(found) != 1:
        raise ValueError("expected exactly one %s in %s" % (SHEET, entry["zip"]))
    source = read(found[0])
    return "sheet", source, sha256(source)


def set_root(path):
    global ROOT, MANIFEST, UNPACK, STAMP, OUTPUT
    ROOT = os.path.abspath(path)
    MANIFEST = os.path.join(ROOT, "DESIGN", "MANIFEST.json")
    UNPACK = os.path.join(ROOT, "dist", "master-latest")
    STAMP = os.path.join(ROOT, "gestaltung", "alfa-interface", "design.stamp.json")
    OUTPUT = os.path.join(ROOT, "alfaos", "Kit", "Sources", "ShellCore", "DesignTokens.swift")


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--root", help="repository root holding DESIGN/ and gestaltung/ (default: this repository)")
    parser.add_argument("--out", help="output file (default: DesignTokens.swift in alfaos/Kit)")
    args = parser.parse_args(argv)
    if args.root:
        set_root(args.root)
    target = args.out or OUTPUT
    try:
        entry = latest_master()
        kind, source, content = read_master(entry)
        stamp = json.loads(read(STAMP).decode("utf-8"))
        for field in STAMP_FIELDS + ("content",):
            if not isinstance(stamp.get(field), str) or not stamp[field].strip():
                raise ValueError("design.stamp.json: %s is missing" % field)
        if stamp["zipSha256"] != entry["zipSha256"]:
            raise ValueError("design.stamp.json: zipSha256 is not the latest master: set it to %s and renew adoptedAt and state" % entry["zipSha256"])
        if stamp["content"] != content:
            raise ValueError("%s changed since its stamp: set content to %s and renew adoptedAt and state" % (SHEET if kind == "sheet" else "contract/", content))
        data = build(source, stamp) if kind == "sheet" else build_contract(source, stamp)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print("design_generate: %s" % error, file=sys.stderr)
        return 2
    if args.check:
        try:
            same = read(target) == data
        except OSError:
            same = False
        print("design_generate: outputs match the source" if same else "design_generate: stale or missing DesignTokens.swift")
        return 0 if same else 1
    with open(target, "wb") as handle:
        handle.write(data)
    print("wrote %s" % target)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
