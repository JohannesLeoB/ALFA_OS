import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / "rules"))

from drawer import RUNNERS  # noqa: E402

errors = []

FORBIDDEN = [
    ("amount", re.compile(r"\d[\d.,]*\s?(?:€|EUR|Euro)\b|(?:€|EUR)\s?\d")),
    ("e-mail address", re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")),
    ("key", re.compile(r"\b(?:sk-[A-Za-z0-9_-]{20,}|gh[pos]_[A-Za-z0-9_]{16,}|github_pat_[A-Za-z0-9_]{16,})")),
]


def schema(name):
    return json.loads((root / "schema" / f"{name}.schema.json").read_text(encoding="utf-8"))


def check(value, rules, where):
    if "enum" in rules and value not in rules["enum"]:
        errors.append(f"{where}: '{value}' is not one of {rules['enum']}")
        return
    kind = rules.get("type")
    types = {"object": dict, "array": list, "string": str, "integer": int, "number": (int, float)}
    if kind and not isinstance(value, types[kind]) or (kind in ("integer", "number") and isinstance(value, bool)):
        errors.append(f"{where}: expected {kind}")
        return
    if kind == "string" and "pattern" in rules and not re.search(rules["pattern"], value):
        errors.append(f"{where}: '{value}' does not match {rules['pattern']}")
    if kind in ("integer", "number") and "minimum" in rules and value < rules["minimum"]:
        errors.append(f"{where}: {value} is below {rules['minimum']}")
    if kind == "array" and "items" in rules:
        for index, item in enumerate(value):
            check(item, rules["items"], f"{where}[{index}]")
    if kind == "object":
        properties = rules.get("properties", {})
        for key in rules.get("required", []):
            if key not in value:
                errors.append(f"{where}: field '{key}' is missing")
        extra = rules.get("additionalProperties", True)
        for key, item in value.items():
            if key in properties:
                check(item, properties[key], f"{where}.{key}")
            elif extra is False:
                errors.append(f"{where}: field '{key}' is not allowed")
            elif isinstance(extra, dict):
                check(item, extra, f"{where}.{key}")


def records(pattern):
    for path in sorted(root.glob(pattern)):
        if path.suffix == ".jsonl":
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if line.strip():
                    yield f"{path.relative_to(root)}:{number}", json.loads(line)
        else:
            yield str(path.relative_to(root)), json.loads(path.read_text(encoding="utf-8"))


def main():
    seen = {}
    loaded = {}
    for kind, pattern in (("source", "sources/*.jsonl"), ("atom", "atoms/*.jsonl"),
                          ("library-entry", "libraries/*/*.json"), ("setup", "setups/*.json")):
        rules = schema(kind)
        loaded[kind] = []
        for where, record in records(pattern):
            check(record, rules, where)
            identifier = record.get("id")
            if identifier in seen:
                errors.append(f"{where}: id '{identifier}' is also in {seen[identifier]}")
            seen[identifier] = where
            loaded[kind].append((where, record))

    sources = {record["id"] for _, record in loaded["source"]}
    atoms = {record["id"] for _, record in loaded["atom"]}
    runner_keys = set(RUNNERS) | {record["attributes"].get("runner_key") for _, record in loaded["library-entry"]}

    for kind in ("atom", "library-entry"):
        for where, record in loaded[kind]:
            for reference in record.get("sources", []):
                if reference.get("id") not in sources:
                    errors.append(f"{where}: source '{reference.get('id')}' does not exist")
            target = record.get("rule")
            if target:
                file_name, _, function = target.partition(":")
                text = (root / file_name).read_text(encoding="utf-8") if (root / file_name).exists() else ""
                if f"def {function}(" not in text:
                    errors.append(f"{where}: rule '{target}' does not exist")
            for key in record.get("applies_to", []):
                if key not in runner_keys:
                    errors.append(f"{where}: applies_to '{key}' is not a known runner")
            if kind == "library-entry" and record["library"] == "hardware":
                key = record["attributes"].get("runner_key")
                if key in RUNNERS and list(RUNNERS[key].nominal_lengths_mm) != record["attributes"].get("nominal_lengths_mm"):
                    errors.append(f"{where}: nominal lengths differ from rules/drawer.py")

    for where, record in loaded["setup"]:
        for name, entry in record["values"].items():
            if "atom" in entry and entry["atom"] not in atoms:
                errors.append(f"{where}.{name}: atom '{entry['atom']}' does not exist")

    for path in sorted(root.rglob("*")):
        if not path.is_file() or ".git" in path.parts or path.suffix not in (".md", ".json", ".jsonl", ".py"):
            continue
        if path.name == "validate.py":
            continue
        text = path.read_text(encoding="utf-8")
        for name, pattern in FORBIDDEN:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"{path.relative_to(root)}:{line}: forbidden pattern ({name})")

    counts = ", ".join(f"{len(items)} {kind}" for kind, items in loaded.items())
    for message in errors:
        print("Error:", message)
    print(f"Checked {counts}. {len(errors)} errors.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
