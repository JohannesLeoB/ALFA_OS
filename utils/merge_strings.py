import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(ROOT, "Resources")
OUTPUT = os.path.join(RESOURCES, "Localizable.xcstrings")
LANGUAGE = "de"
LANGUAGES = ("de", "en")
BODY = r'[a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9_]+)+'
CALL = re.compile(r'(?:\b(?:string|text|format|key|LocalizedStringKey|LocalizationValue)\(\s*|\b(?:title|label|action|text|hint|message|help|placeholder)Key\s*[:=]\s*)"(%s)"' % BODY)
BRANCH = re.compile(r'\?\s*"(%s)"\s*:\s*"(%s)"' % (BODY, BODY))
CODE_DIRS = ("App", "Sources")


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def entry(texts):
    return {"localizations": {language: unit(texts[language]) for language in LANGUAGES if language in texts}}


def value_of(item, language=LANGUAGE):
    return item.get("localizations", {}).get(language, {}).get("stringUnit", {}).get("value")


def read_catalog(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)["strings"]


def read_modules():
    merged, owner = {}, {}
    for path in sorted(glob.glob(os.path.join(RESOURCES, "*.localizable.json"))):
        with open(path, encoding="utf-8") as handle:
            keys = json.load(handle)["keys"]
        for key, item in keys.items():
            if item.get(LANGUAGE) is None:
                continue
            texts = {language: item[language] for language in LANGUAGES if language in item}
            if key in merged and merged[key] != texts:
                print("conflict between modules: %s (%s, %s)" % (key, owner[key], os.path.basename(path)), file=sys.stderr)
                continue
            merged[key] = texts
            owner[key] = os.path.basename(path)
    return merged


def merge(base, modules):
    strings = dict(base)
    for key, texts in modules.items():
        if key not in strings:
            strings[key] = entry(texts)
            continue
        for language, text in texts.items():
            current = value_of(strings[key], language)
            if current is None:
                item = dict(strings[key])
                item["localizations"] = dict(item.get("localizations", {}), **{language: unit(text)})
                strings[key] = item
            elif current != text:
                print("kept existing %s text for %s" % (language, key), file=sys.stderr)
    return strings


def render(strings):
    body = {"sourceLanguage": LANGUAGE, "strings": {key: strings[key] for key in sorted(strings)}, "version": "1.0"}
    return (json.dumps(body, ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n").encode("utf-8")


def referenced():
    found = {}
    for folder in CODE_DIRS:
        for path in glob.glob(os.path.join(ROOT, folder, "**", "*.swift"), recursive=True):
            with open(path, encoding="utf-8") as handle:
                source = handle.read()
            keys = CALL.findall(source) + [key for pair in BRANCH.findall(source) for key in pair]
            for key in keys:
                found.setdefault(key, set()).add(os.path.relpath(path, ROOT))
    return found


def missing(strings):
    prefixes = {key.split(".")[0] for key in strings}
    result = {}
    for key, files in referenced().items():
        if key.split(".")[0] not in prefixes or value_of(strings.get(key, {})):
            continue
        if any(other.startswith(key + ".") for other in strings):
            continue
        result[key] = sorted(files)
    return result


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--legacy", help="catalog to start from; defaults to the existing output")
    parser.add_argument("--check", action="store_true")
    options = parser.parse_args(argv)
    base_path = options.legacy or (OUTPUT if os.path.exists(OUTPUT) else None)
    base = read_catalog(base_path) if base_path else {}
    strings = merge(base, read_modules())
    data = render(strings)
    if options.check:
        current = open(OUTPUT, "rb").read() if os.path.exists(OUTPUT) else b""
        if current != data:
            print("stale: Resources/Localizable.xcstrings", file=sys.stderr)
            return 1
    else:
        with open(OUTPUT, "wb") as handle:
            handle.write(data)
        print("wrote Resources/Localizable.xcstrings (%d keys)" % len(strings))
    for key, files in sorted(missing(strings).items()):
        print("no de value: %s (%s)" % (key, ", ".join(files)), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
