import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import json
import re

from data import by_id, load, root, setup_chain

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
    if kind and (not isinstance(value, types[kind]) or (kind in ("integer", "number") and isinstance(value, bool))):
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


def main():
    loaded = load()
    seen = {}
    for kind, items in loaded.items():
        rules = schema(kind)
        for where, record in items:
            check(record, rules, where)
            identifier = record.get("id")
            if identifier in seen:
                errors.append(f"{where}: id '{identifier}' is also in {seen[identifier]}")
            seen[identifier] = where

    sources = set(by_id(loaded, "source"))
    concepts = by_id(loaded, "concept")
    atoms = set(by_id(loaded, "atom"))
    libraries = set(by_id(loaded, "library-entry"))
    media = set(by_id(loaded, "media"))
    setups = by_id(loaded, "setup")
    runner_keys = set(RUNNERS) | {record["attributes"].get("runner_key") for _, record in loaded["library-entry"]}
    targets = {"ATM": atoms, "CON": set(concepts), "LIB": libraries, "MED": media}

    for where, record in loaded["concept"]:
        for key in ("broader", "part_of"):
            if record.get(key) and record[key] not in concepts:
                errors.append(f"{where}: {key} '{record[key]}' does not exist")

    for kind in ("atom", "library-entry", "media", "catalog-section"):
        for where, record in loaded[kind]:
            for reference in record.get("sources", []):
                if reference.get("id") not in sources:
                    errors.append(f"{where}: source '{reference.get('id')}' does not exist")
            if kind == "catalog-section" and record["pdf_to"] < record["pdf_from"]:
                errors.append(f"{where}: pdf_to is before pdf_from")
            if kind in ("media", "catalog-section") and record.get("source") not in sources:
                errors.append(f"{where}: source '{record.get('source')}' does not exist")
            for concept in record.get("concepts", []):
                if concept not in concepts:
                    errors.append(f"{where}: concept '{concept}' does not exist")
            for link in record.get("links", []):
                if link.get("to") not in targets.get(link.get("to", "")[:3], set()):
                    errors.append(f"{where}: link target '{link.get('to')}' does not exist")
            for atom in record.get("atoms", []):
                if atom not in atoms:
                    errors.append(f"{where}: atom '{atom}' does not exist")
            target = record.get("rule")
            if target:
                file_name, _, function = target.partition(":")
                path = root / file_name
                if not path.exists() or f"def {function}(" not in path.read_text(encoding="utf-8"):
                    errors.append(f"{where}: rule '{target}' does not exist")
            for key in record.get("applies_to", []):
                if key not in runner_keys:
                    errors.append(f"{where}: applies_to '{key}' is not a known runner")
            if kind == "library-entry" and record["library"] == "hardware":
                key = record["attributes"].get("runner_key")
                if key in RUNNERS and list(RUNNERS[key].nominal_lengths_mm) != record["attributes"].get("nominal_lengths_mm"):
                    errors.append(f"{where}: nominal lengths differ from rules/drawer.py")

    for where, record in loaded["setup"]:
        try:
            setup_chain(setups, record["id"])
        except ValueError as error:
            errors.append(f"{where}: {error}")
        for name, entry in record["values"].items():
            if "atom" in entry and entry["atom"] not in atoms:
                errors.append(f"{where}.{name}: atom '{entry['atom']}' does not exist")

    for path in sorted(root.rglob("*")):
        if not path.is_file() or ".git" in path.parts or "build" in path.parts:
            continue
        if path.suffix not in (".md", ".json", ".jsonl", ".py", ".sql") or path.name == "validate.py":
            continue
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(root).parts
        for name, pattern in FORBIDDEN:
            if name == "amount" and relative[0] in ("prices", "tools"):
                continue
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
