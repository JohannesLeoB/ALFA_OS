import json
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent

KINDS = (
    ("source", "sources/*.jsonl"),
    ("concept", "concepts/*.jsonl"),
    ("atom", "atoms/*.jsonl"),
    ("media", "media/*.jsonl"),
    ("library-entry", "libraries/*/*.json"),
    ("setup", "setups/*.json"),
)


def records(pattern):
    for path in sorted(root.glob(pattern)):
        if path.suffix == ".jsonl":
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if line.strip():
                    yield f"{path.relative_to(root)}:{number}", json.loads(line)
        else:
            yield str(path.relative_to(root)), json.loads(path.read_text(encoding="utf-8"))


def load():
    return {kind: list(records(pattern)) for kind, pattern in KINDS}


def by_id(loaded, kind):
    return {record["id"]: record for _, record in loaded[kind]}


def setup_chain(setups, identifier):
    chain = []
    seen = set()
    while identifier:
        if identifier in seen or identifier not in setups:
            raise ValueError(f"setup chain breaks at '{identifier}'")
        seen.add(identifier)
        chain.append(setups[identifier])
        identifier = setups[identifier].get("parent")
    return list(reversed(chain))


def resolve_setup(setups, identifier):
    values = {}
    for layer in setup_chain(setups, identifier):
        for key, entry in layer["values"].items():
            values[key] = dict(entry, layer=layer["id"])
    return values
