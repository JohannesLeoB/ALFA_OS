import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Resources", "tokens.json")
OUTPUT = os.path.join(ROOT, "Sources", "Design", "Model")
INDENT = "    "
KEYWORDS = {"default", "in", "is", "as", "if", "else", "for", "func", "let", "var", "class", "enum", "struct", "self",
            "super", "true", "false", "nil", "return", "where", "while", "case", "switch", "init", "internal", "private",
            "public", "static", "extension", "protocol", "operator", "subscript", "import", "repeat", "guard", "do"}
MODES = {"light": "light", "dark": "dark", "hell": "light", "dunkel": "dark"}
INK_ROLES = ("primary", "secondary", "tertiary", "line")


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
    return "ColorValue(%s, %s, %s, %s)" % (num(c[0]), num(c[1]), num(c[2]), num(value.get("alpha", 1)))


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


def hex_rgb(text):
    h = text.lstrip("#")
    parts = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return "ColorValue(%s, %s, %s, 1.0)" % tuple(num(round(p, 4)) for p in parts)


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


def flatten(node, prefix=""):
    items = []
    for key, leaf in children(node):
        name = prefix + cap(key) if prefix else key
        if is_leaf(leaf):
            items.append((name, leaf))
        elif isinstance(leaf, dict):
            items += flatten(leaf, name)
    return items


def numeric_block(title, node, whole=False, nested=False):
    lines = ["%spublic enum %s {" % (INDENT, title)]
    leaves = flatten(node) if nested else [(key, leaf) for key, leaf in children(node) if is_leaf(leaf)]
    for key, leaf in leaves:
        text = str(int(leaf["$value"])) if whole else number(leaf["$value"])
        if text is not None:
            lines.append("%s%spublic static let %s = %s" % (INDENT, INDENT, ident(key), text))
    lines.append("%s}" % INDENT)
    return lines


REFERENCES = {"typography.size": "TextSize", "typography.weight": "Weight", "typography.lineHeight": "LineHeight",
              "typography.tracking": "Tracking", "motion.duration": "Duration", "motion.easing": "Easing"}


def value_of(source, value):
    return resolve(source, value)["$value"] if isinstance(value, str) else value


def reference(source, value, render):
    if isinstance(value, str):
        parts = value.strip("{}").split(".")
        group = REFERENCES.get(".".join(parts[:-1]))
        if group:
            return "%s.%s" % (group, ident(parts[-1]))
    return render(value_of(source, value))


def text_style(source, value):
    size = reference(source, value["fontSize"], lambda v: num(dimension(v)))
    weight = reference(source, value["fontWeight"], lambda v: str(int(v)))
    tracking = reference(source, value.get("letterSpacing", 0), lambda v: num(dimension(v)))
    line = value["lineHeight"]
    line_type = resolve(source, line).get("$type") if isinstance(line, str) else None
    height = reference(source, line, lambda v: num(dimension(v)))
    if line_type == "number":
        height = "%s * %s" % (height, size)
    return "TypeStyle(size: %s, weight: %s, tracking: %s, lineHeight: %s)" % (size, weight, tracking, height)


def transition(source, value):
    seconds_of = lambda v: num(seconds(v))
    return "Timing(duration: %s, delay: %s, easing: %s)" % (
        reference(source, value["duration"], seconds_of), reference(source, value["delay"], seconds_of),
        reference(source, value["timingFunction"], lambda v: "CubicBezier(x1: %s, y1: %s, x2: %s, y2: %s)" % tuple(num(c) for c in v)))


def surface_file(source):
    out = ["public enum Surface {"]
    for key, leaf in flatten(source["surface"]):
        out.append("%spublic static let %s: [ShadowLayer] = %s" % (INDENT, ident(key), shadow_expr(source, leaf["$value"])))
    out.append("}")
    return out


def component_block(node):
    lines = ["%spublic enum Component {" % INDENT]
    for key, leaf in children(node):
        ref = leaf if isinstance(leaf, str) else leaf["$value"]
        target = ref.strip("{}").split(".")
        expr = "%s.%s" % (cap(target[0]), ".".join([ident(p) for p in target[1:]]))
        lines.append("%s%spublic static let %s = %s" % (INDENT, INDENT, ident(key), expr))
    lines.append("%s}" % INDENT)
    return lines


def tokens_file(source):
    out = ["public enum Tokens {"]
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
    out += numeric_block("Layer", source["layer"], whole=True, nested=True)
    out += numeric_block("Tracking", source["typography"]["tracking"])
    out += numeric_block("Scale", source["scale"])
    out += numeric_block("Ratio", source["ratio"])
    out += scalar_block("TextStyle", source["typography"]["textStyle"], lambda l: text_style(source, l["$value"]))
    out += scalar_block("Transition", source["motion"]["transition"], lambda l: transition(source, l["$value"]))
    out += component_block(source["component"])
    out.append("}")
    out += ["", "public struct TypeStyle: Sendable, Equatable {", "%spublic let size: Double" % INDENT, "%spublic let weight: Int" % INDENT,
            "%spublic let tracking: Double" % INDENT, "%spublic let lineHeight: Double" % INDENT, "}"]
    out += ["", "public struct Timing: Sendable, Equatable {", "%spublic let duration: Double" % INDENT,
            "%spublic let delay: Double" % INDENT, "%spublic let easing: CubicBezier" % INDENT, "}"]
    out += ["", "public struct StackStep: Sendable, Equatable {", "%spublic let surface: ColorValue" % INDENT,
            "%spublic let ink: ColorValue" % INDENT, "}", "", "public extension Tokens {"]
    for mode in ("light", "dark"):
        steps = ", ".join("StackStep(surface: %s, ink: %s)" % (rgb(s["surface"]["$value"]), rgb(s["ink"]["$value"])) for s in source["stack"][mode])
        out.append("%sstatic let stack%s: [StackStep] = [%s]" % (INDENT, cap(mode), steps))
    out.append("}")
    return out


def colors_file(source):
    light = source["color"]["light"]
    keys = [k for k, v in children(light) if is_leaf(v)]
    out = ["public struct Colors: Sendable, Equatable {"]
    for key in keys:
        out.append("%spublic let %s: ColorValue" % (INDENT, ident(key)))
    out += ["}", "", "public extension Colors {"]

    def value(node, fallback=None):
        items = []
        for key in keys:
            leaf = node.get(key) or (fallback or {}).get(key)
            items.append("%s: %s" % (ident(key), color_expr(source, leaf["$value"])))
        return "Colors(" + ", ".join(items) + ")"

    out.append("%sstatic let light = %s" % (INDENT, value(light)))
    out.append("%sstatic let dark = %s" % (INDENT, value(source["color"]["dark"])))
    out.append("%sstatic let lightGray = %s" % (INDENT, value(source["color"]["lightGrayOverrides"], light)))
    out.append("}")
    return out, keys


def moods_file(node):
    keys = [k for k, v in children(node) if is_leaf(v)]
    out = ["public struct Moods: Sendable, Equatable {"]
    for key in keys:
        out.append("%spublic let %s: ColorValue" % (INDENT, ident(key)))
    out += ["}", "", "public extension Moods {"]
    for mode in ("light", "dark"):
        items = ", ".join("%s: %s" % (ident(k), hex_rgb(node[k]["$value"][mode])) for k in keys)
        out.append("%sstatic let %s = Moods(%s)" % (INDENT, mode, items))
    out.append("}")
    return out


def shadows_file(source):
    light, dark = source["shadow"]["light"], source["shadow"]["dark"]
    keys = [k for k, v in children(light) if is_leaf(v) and k in dark]
    single = [(m, k) for m in ("light", "dark") for k, v in children(source["shadow"][m])
              if is_leaf(v) and k not in source["shadow"]["dark" if m == "light" else "light"]]
    out = ["public struct Shadows: Sendable, Equatable {"]
    for key in keys:
        out.append("%spublic let %s: [ShadowLayer]" % (INDENT, ident(key)))
    out += ["}", "", "public extension Shadows {"]
    for mode in ("light", "dark"):
        items = ", ".join("%s: %s" % (ident(k), shadow_expr(source, source["shadow"][mode][k]["$value"])) for k in keys)
        out.append("%sstatic let %s = Shadows(%s)" % (INDENT, mode, items))
    for mode, key in single:
        out.append("%sstatic let %s%s: [ShadowLayer] = %s" % (INDENT, ident(key), cap(mode), shadow_expr(source, source["shadow"][mode][key]["$value"])))
    out.append("}")
    return out


def ink_file(source, color_keys):
    constants = source["constants"]
    out = ["public struct InkSet {"]
    for role in INK_ROLES:
        out.append("%spublic let %s: KeyPath<Colors, ColorValue>" % (INDENT, role))
    out.append("")
    for name, roles in constants["ink"].items():
        if sorted(roles) != sorted(INK_ROLES):
            raise ValueError("constants.ink.%s must define %s" % (name, ", ".join(INK_ROLES)))
        for role in INK_ROLES:
            if roles[role] not in color_keys:
                raise ValueError("constants.ink.%s.%s: %s is not a color token" % (name, role, roles[role]))
        args = ", ".join("%s: \\.%s" % (role, ident(roles[role])) for role in INK_ROLES)
        out.append("%spublic static var %s: InkSet { InkSet(%s) }" % (INDENT, ident(name), args))
    out += ["", "%spublic static func of(_ inverted: Bool) -> InkSet { inverted ? .inverse : .lane }" % INDENT, "}"]
    return out


def render(lines):
    return ("\n".join(lines) + "\n").encode("utf-8")


def build(source):
    colors, color_keys = colors_file(source)
    return {
        "Tokens.swift": render(tokens_file(source)),
        "Colors.swift": render(colors),
        "Moods.swift": render(moods_file(source["color"]["mood"])),
        "Shadows.swift": render(shadows_file(source)),
        "InkSet.swift": render(ink_file(source, color_keys)),
        "Surface.swift": render(surface_file(source)),
    }


def read_or_none(path):
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except OSError:
        return None


def main(argv):
    try:
        with open(SOURCE, "rb") as handle:
            source = json.loads(handle.read().decode("utf-8"))
        outputs = build(source)
    except (OSError, ValueError, KeyError) as error:
        print("generate_tokens: %s" % error, file=sys.stderr)
        return 2
    if "--check" in argv:
        stale = [name for name, data in sorted(outputs.items()) if read_or_none(os.path.join(OUTPUT, name)) != data]
        for name in stale:
            print("stale or missing: %s" % name, file=sys.stderr)
        return 1 if stale else 0
    os.makedirs(OUTPUT, exist_ok=True)
    for name, data in sorted(outputs.items()):
        with open(os.path.join(OUTPUT, name), "wb") as handle:
            handle.write(data)
        print("wrote %s" % os.path.join("Sources", "Design", "Model", name))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
