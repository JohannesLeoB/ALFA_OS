#!/usr/bin/env python3
"""Validate a JSON file against a JSON Schema (draft 2020-12 subset used by the ALFA schemas).

Supported keywords: $ref (local), type, enum, const, required, properties, patternProperties,
additionalProperties, propertyNames, items, prefixItems, minItems, maxItems, minimum, maximum,
pattern, minLength, maxLength, minProperties, anyOf, allOf, if/then/else.
Exit 0 = valid, 1 = errors, 2 = usage.
Usage: validate.py SCHEMA FILE [--max N]
       validate.py CONTRACT_DIR   (all required files must exist and hold JSON; each one with a schema is checked
                                  against it; akte.json and werte-abgleich.json have no schema yet)
"""
import json
import re
import sys

TYPES = {
    "object": lambda v: isinstance(v, dict),
    "array": lambda v: isinstance(v, list),
    "string": lambda v: isinstance(v, str),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "boolean": lambda v: isinstance(v, bool),
    "null": lambda v: v is None,
}


class Validator:
    def __init__(self, root):
        self.root = root

    def resolve(self, ref):
        if not ref.startswith("#/"):
            raise ValueError("only local $ref supported: %s" % ref)
        node = self.root
        for part in ref[2:].split("/"):
            node = node[part.replace("~1", "/").replace("~0", "~")]
        return node

    def errors(self, schema, value, path):
        out = []
        if "$ref" in schema:
            out += self.errors(self.resolve(schema["$ref"]), value, path)
        t = schema.get("type")
        if t is not None:
            names = t if isinstance(t, list) else [t]
            if not any(TYPES[n](value) for n in names):
                return out + ["%s: type %s expected" % (path, "/".join(names))]
        if "enum" in schema and value not in schema["enum"]:
            out.append("%s: value %r not in %s" % (path, value, schema["enum"]))
        if "const" in schema and value != schema["const"]:
            out.append("%s: value %r is not %r" % (path, value, schema["const"]))
        if isinstance(value, str):
            if "pattern" in schema and not re.search(schema["pattern"], value):
                out.append("%s: %r does not match %s" % (path, value, schema["pattern"]))
            if len(value) < schema.get("minLength", 0):
                out.append("%s: string too short" % path)
            if "maxLength" in schema and len(value) > schema["maxLength"]:
                out.append("%s: string too long" % path)
        if TYPES["number"](value):
            if "minimum" in schema and value < schema["minimum"]:
                out.append("%s: %r < %r" % (path, value, schema["minimum"]))
            if "maximum" in schema and value > schema["maximum"]:
                out.append("%s: %r > %r" % (path, value, schema["maximum"]))
        if isinstance(value, dict):
            for key in schema.get("required", []):
                if key not in value:
                    out.append("%s: missing %s" % (path, key))
            if len(value) < schema.get("minProperties", 0):
                out.append("%s: too few properties" % path)
            props = schema.get("properties", {})
            pats = schema.get("patternProperties", {})
            for key, sub in value.items():
                p = "%s/%s" % (path, key)
                if "propertyNames" in schema:
                    out += self.errors(schema["propertyNames"], key, p + "(name)")
                matched = False
                if key in props:
                    matched = True
                    out += self.errors(props[key], sub, p)
                for pat, s in pats.items():
                    if re.search(pat, key):
                        matched = True
                        out += self.errors(s, sub, p)
                if not matched:
                    extra = schema.get("additionalProperties", True)
                    if extra is False:
                        out.append("%s: property not allowed" % p)
                    elif isinstance(extra, dict):
                        out += self.errors(extra, sub, p)
        if isinstance(value, list):
            if len(value) < schema.get("minItems", 0):
                out.append("%s: too few items" % path)
            if "maxItems" in schema and len(value) > schema["maxItems"]:
                out.append("%s: too many items" % path)
            prefix = schema.get("prefixItems", [])
            for i, item in enumerate(value):
                if i < len(prefix):
                    out += self.errors(prefix[i], item, "%s[%d]" % (path, i))
                elif "items" in schema:
                    out += self.errors(schema["items"], item, "%s[%d]" % (path, i))
        for sub in schema.get("allOf", []):
            out += self.errors(sub, value, path)
        if "anyOf" in schema:
            if not any(not self.errors(s, value, path) for s in schema["anyOf"]):
                out.append("%s: matches no allowed form" % path)
        if "if" in schema:
            if not self.errors(schema["if"], value, path):
                if "then" in schema:
                    out += self.errors(schema["then"], value, path)
            elif "else" in schema:
                out += self.errors(schema["else"], value, path)
        return out


MAP = [(".tokens.json", "alfa.tokens.schema.json"), ("alfa.resolver.json", "alfa.resolver.schema.json"),
       ("components.json", "components.schema.json"), ("views.json", "views.schema.json"),
       ("texts.json", "texts.schema.json"), ("changes.json", "changes.schema.json")]
REQUIRED = ["base.tokens.json", "theme-light.tokens.json", "theme-dark.tokens.json", "alfa.resolver.json",
            "components.json", "views.json", "texts.json", "changes.json", "akte.json", "werte-abgleich.json"]
NO_SCHEMA = ("akte.json", "werte-abgleich.json")


def read_json(path):
    """Return (data, error). A missing, empty or unreadable file gives an error text, never a crash."""
    import os
    if not os.path.isfile(path):
        return None, "file is missing"
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except (OSError, UnicodeDecodeError) as error:
        return None, "file is unreadable (%s)" % error
    if not text.strip():
        return None, "file is empty"
    try:
        return json.loads(text), None
    except ValueError as error:
        return None, "invalid JSON (%s)" % error


def contract(folder):
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    bad = 0
    names = list(REQUIRED)
    if os.path.isdir(folder):
        names += [n for n in sorted(os.listdir(folder)) if n not in names and any(n.endswith(e) for e, _ in MAP)]
    for name in names:
        data, problem = read_json(os.path.join(folder, name))
        errs = [problem] if problem else []
        if not errs and name in NO_SCHEMA and (not data or not isinstance(data, (dict, list))):
            errs = ["no content: a non-empty object or array is required"]
        schema = next((s for end, s in MAP if name.endswith(end)), None)
        if not errs and schema is not None:
            sch, problem = read_json(os.path.join(here, schema))
            if problem:
                errs = ["schema %s: %s" % (schema, problem)]
            else:
                errs = Validator(sch).errors(sch, data, "#")
        print("%s: %s" % (name, "%d error(s)" % len(errs) if errs else "valid"))
        for e in errs[:20]:
            print("  " + e)
        bad += bool(errs)
    print("contract: %s" % ("invalid" if bad else "valid"))
    return 1 if bad else 0


def main(argv):
    import os
    if len(argv) == 1 and os.path.isdir(argv[0]):
        return contract(argv[0])
    if len(argv) < 2:
        print(__doc__)
        return 2
    limit = int(argv[argv.index("--max") + 1]) if "--max" in argv else 50
    with open(argv[0], encoding="utf-8") as f:
        schema = json.load(f)
    with open(argv[1], encoding="utf-8") as f:
        data = json.load(f)
    errs = Validator(schema).errors(schema, data, "#")
    for e in errs[:limit]:
        print(e)
    print("%d error(s)" % len(errs) if errs else "valid")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
