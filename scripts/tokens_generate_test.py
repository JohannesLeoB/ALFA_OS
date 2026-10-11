#!/usr/bin/env python3
"""Tests for scripts/tokens_generate.py: the one generator of web variables and Swift keys.

Every case that changes a file works on a copy in a temporary folder.
Run: python3 scripts/tokens_generate_test.py
"""
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SCRIPT = os.path.join(HERE, "tokens_generate.py")
SOURCE = os.path.join(REPO, "gestaltung", "alfa-interface", "tokens.json")
WEB = os.path.join(REPO, "gestaltung", "alfa-interface", "tokens.css")
SWIFT = os.path.join(REPO, "app", "Sources", "AppTheme", "GeneratedTokens.swift")
TOOLS_DIR = "plan/werk" + "zeuge"
ORACLE = os.path.join(REPO, TOOLS_DIR, "umbau", "tokens_css.py")
CHECK_SCRIPT = os.path.join(HERE, "pruefen.sh")

ISSUE, WHEN, WHO = "#11", "2026-10-11", "Ch" + "ef"
WHO_VALUES = ("Jo" + "hannes", WHO)
HEAD = re.compile(r"^// tokens\.json version (\S+) sha256 ([0-9a-f]{64})$")
KEY_LINE = re.compile(r'^\s*static let (\w+) = ThemeKey\("([^"]+)"\)\s*$', re.M)
CSS_NAME = re.compile(r"^\s*--([a-z0-9-]+):", re.M)


def legit(criterion, where, threshold="none"):
    def mark(test):
        test.legit = dict(criterion=criterion, where=where, threshold=threshold, issue=ISSUE, when=WHEN, who=WHO)
        return test
    return mark


def read_bytes(path):
    with open(path, "rb") as handle:
        return handle.read()


def read_text(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def sha256(path):
    return hashlib.sha256(read_bytes(path)).hexdigest()


def camel(name):
    first, *rest = name.split("-")
    return first + "".join(part[:1].upper() + part[1:] for part in rest)


def variable_names(css):
    names = []
    for name in CSS_NAME.findall(css):
        if name not in names:
            names.append(name)
    return names


def swift_keys(text):
    return KEY_LINE.findall(text)


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=1, ensure_ascii=False)
        handle.write("\n")


def extended(data):
    probe = json.loads(json.dumps(data))
    probe["color"]["tokens"] += [
        {"name": "color-probe-pair", "value": {"light": "rgba(1, 2, 3, 0.5)", "dark": "#abcdef"}, "usage": "probe"},
        {"name": "color-probe-alias", "value": "{color-probe-pair}", "usage": "probe"},
    ]
    probe["shadow"]["tokens"].append({
        "name": "shadow-probe-stack",
        "value": {"light": "inset 0 1px 0 #ffffff, 0 8px 24px 0 rgba(0,0,0,0.1), 0 0 0 1px #e8e8e8", "dark": "none"},
        "usage": "probe"})
    probe["stroke"]["tokens"].append({"name": "stroke-probe-wide", "value": "3px", "usage": "probe"})
    probe["motion"] = {"note": "probe", "tokens": [
        {"name": "motion-spring-probe", "value": "spring(3.2, 14, 7.5)", "usage": "probe"},
        {"name": "motion-duration-probe", "value": "1.2s", "usage": "probe"}]}
    return probe


class Work:
    def __init__(self, case, data=None):
        self.tmp = tempfile.TemporaryDirectory(prefix="tokens-generate-test-")
        case.addCleanup(self.tmp.cleanup)
        self.source = os.path.join(self.tmp.name, "tokens.json")
        self.web = os.path.join(self.tmp.name, "tokens.css")
        self.swift = os.path.join(self.tmp.name, "GeneratedTokens.swift")
        if data is None:
            shutil.copyfile(SOURCE, self.source)
        else:
            write_json(self.source, data)

    def run(self, *extra, check=False):
        args = [sys.executable, SCRIPT, "--source", self.source, "--web", self.web, "--swift", self.swift, *extra]
        if check:
            args.append("--check")
        proc = subprocess.run(args, cwd=self.tmp.name, capture_output=True, text=True)
        return proc.returncode, proc.stdout + proc.stderr

    def generate(self, case):
        rc, out = self.run()
        case.assertEqual(rc, 0, out)

    def check(self):
        return self.run(check=True)

    def load(self):
        with open(self.source, encoding="utf-8") as handle:
            return json.load(handle)

    def mutate(self, change):
        data = self.load()
        change(data)
        write_json(self.source, data)


def change_first_light_colour(data):
    for token in data["color"]["tokens"]:
        if isinstance(token["value"], dict):
            token["value"]["light"] = "#010203" if token["value"]["light"] != "#010203" else "#040506"
            return
    raise AssertionError("no colour token with modes")


def change_source_text_only(data):
    data["meta"]["source"] = data["meta"]["source"] + " changed"


class Check(unittest.TestCase):
    @legit("The check mode is green on the pulled state", "gestaltung/alfa-interface and the generated Swift file",
           "exit 0")
    def test_check_is_green_on_the_current_state(self):
        proc = subprocess.run([sys.executable, SCRIPT, "--check"], cwd=REPO, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    @legit("The check mode is red as soon as a token value changes without regenerating", "copy of tokens.json",
           "1 changed value")
    def test_check_is_red_after_a_value_change_without_regenerating(self):
        work = Work(self)
        work.generate(self)
        rc, out = work.check()
        self.assertEqual(rc, 0, out)
        work.mutate(change_first_light_colour)
        rc, out = work.check()
        self.assertNotEqual(rc, 0, out)
        self.assertTrue("tokens.css" in out or "GeneratedTokens.swift" in out, out)
        work.generate(self)
        rc, out = work.check()
        self.assertEqual(rc, 0, out)

    @legit("The Swift head covers the whole source file, so any change of the file turns the check red",
           "copy of tokens.json", "1 changed text outside the values")
    def test_check_is_red_after_a_change_outside_the_values(self):
        work = Work(self)
        work.generate(self)
        before = read_bytes(work.web)
        work.mutate(change_source_text_only)
        rc, out = work.run(check=True)
        self.assertNotEqual(rc, 0, out)
        work.generate(self)
        self.assertEqual(read_bytes(work.web), before)
        self.assertEqual(work.check()[0], 0)

    @legit("The check mode is red when the generated Swift file was edited by hand", "GeneratedTokens.swift",
           "3 kinds of edit")
    def test_check_is_red_when_the_swift_file_is_edited_by_hand(self):
        edits = {
            "appended line": lambda text: text + "// by hand\n",
            "renamed key": lambda text: text.replace("static let ", "static let x", 1),
            "head sha256": lambda text: re.sub(r"sha256 [0-9a-f]", "sha256 z", text, count=1),
        }
        for label, edit in edits.items():
            with self.subTest(edit=label):
                work = Work(self)
                work.generate(self)
                before = read_text(work.swift)
                self.assertNotEqual(edit(before), before)
                with open(work.swift, "w", encoding="utf-8") as handle:
                    handle.write(edit(before))
                rc, out = work.check()
                self.assertNotEqual(rc, 0, out)
                self.assertIn("GeneratedTokens.swift", out)

    @legit("The check mode is red when the web file was edited by hand", "tokens.css", "1 appended line")
    def test_check_is_red_when_the_web_file_is_edited_by_hand(self):
        work = Work(self)
        work.generate(self)
        with open(work.web, "a", encoding="utf-8") as handle:
            handle.write(":root { --color-by-hand: #ff0000; }\n")
        rc, out = work.check()
        self.assertNotEqual(rc, 0, out)
        self.assertIn("tokens.css", out)

    @legit("The check mode is red when an output file is missing", "tokens.css and GeneratedTokens.swift",
           "2 missing files")
    def test_check_is_red_when_an_output_file_is_missing(self):
        for which in ("web", "swift"):
            with self.subTest(missing=which):
                work = Work(self)
                work.generate(self)
                os.remove(getattr(work, which))
                rc, out = work.check()
                self.assertNotEqual(rc, 0, out)

    @legit("The check mode writes nothing", "tokens.css and GeneratedTokens.swift", "0 changed bytes")
    def test_check_mode_does_not_write_the_outputs(self):
        work = Work(self)
        work.generate(self)
        work.mutate(change_first_light_colour)
        before = (read_bytes(work.web), read_bytes(work.swift))
        work.check()
        self.assertEqual((read_bytes(work.web), read_bytes(work.swift)), before)

    @legit("The check mode is part of the check script", "scripts/pruefen.sh", "1 active line")
    def test_check_script_runs_the_check_mode(self):
        lines = [line.strip() for line in read_text(CHECK_SCRIPT).splitlines()]
        active = [line for line in lines if "tokens_generate.py" in line and "--check" in line and not line.startswith("#")]
        self.assertTrue(active, "scripts/pruefen.sh has no active tokens_generate.py --check line")


class WebOutput(unittest.TestCase):
    @unittest.skipUnless(os.path.exists(ORACLE), "the old tool is the oracle")
    @legit("The web variables are byte-equal with the output of the old tool", TOOLS_DIR + "/umbau/tokens_css.py",
           "0 differing bytes")
    def test_web_variables_are_byte_equal_with_the_old_tool(self):
        probes = {"live source": None, "source with new kinds of token": extended(json.loads(read_text(SOURCE)))}
        for label, data in probes.items():
            with self.subTest(source=label):
                work = Work(self, data)
                work.generate(self)
                expected = os.path.join(work.tmp.name, "expected.css")
                done = subprocess.run([sys.executable, ORACLE, work.source, expected], capture_output=True, text=True)
                self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
                self.assertEqual(read_bytes(work.web), read_bytes(expected))

    @legit("The committed web file is what the generator writes", "gestaltung/alfa-interface/tokens.css",
           "0 differing bytes")
    def test_committed_web_file_equals_the_generated_output(self):
        work = Work(self)
        work.generate(self)
        self.assertEqual(read_bytes(work.web), read_bytes(WEB))

    @legit("Generating twice gives the same bytes", "tokens.css and GeneratedTokens.swift", "2 runs")
    def test_generating_twice_gives_the_same_bytes(self):
        first, second = Work(self), Work(self)
        first.generate(self)
        second.generate(self)
        second.generate(self)
        for name in ("web", "swift"):
            with self.subTest(output=name):
                self.assertEqual(read_bytes(getattr(first, name)), read_bytes(getattr(second, name)))
                self.assertEqual(sha256(getattr(first, name)), sha256(getattr(second, name)))


class SwiftOutput(unittest.TestCase):
    @legit("The Swift file starts with a head of version and sha256 of the source", "GeneratedTokens.swift line 1",
           "64 hex digits")
    def test_swift_head_carries_version_and_sha256_of_the_source(self):
        work = Work(self)
        work.generate(self)
        match = HEAD.match(read_text(work.swift).splitlines()[0])
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), str(work.load()["version"]))
        self.assertEqual(match.group(2), sha256(work.source))
        work.mutate(change_first_light_colour)
        work.generate(self)
        again = HEAD.match(read_text(work.swift).splitlines()[0])
        self.assertEqual(again.group(2), sha256(work.source))
        self.assertNotEqual(again.group(2), match.group(2))

    @legit("Every web variable has one Swift key whose name is the variable name in camelCase", "GeneratedTokens.swift",
           "1 key per variable")
    def test_swift_keys_are_the_web_variable_names_in_camel_case(self):
        work = Work(self)
        work.generate(self)
        names = variable_names(read_text(work.web))
        keys = swift_keys(read_text(work.swift))
        self.assertGreater(len(names), 100)
        self.assertEqual(sorted(name for _, name in keys), sorted(names))
        for identifier, name in keys:
            with self.subTest(name=name):
                self.assertEqual(identifier, camel(name))
        self.assertIn("static let all", read_text(work.swift))

    @legit("A new token in the source reaches the web file and the Swift file without any hand work",
           "copy of tokens.json", "5 new tokens")
    def test_a_new_token_in_the_source_reaches_both_outputs(self):
        work = Work(self, extended(json.loads(read_text(SOURCE))))
        work.generate(self)
        css = read_text(work.web)
        keys = dict((name, identifier) for identifier, name in swift_keys(read_text(work.swift)))
        expected = {
            "color-probe-pair": "colorProbePair",
            "color-probe-alias": "colorProbeAlias",
            "shadow-probe-stack": "shadowProbeStack",
            "stroke-probe-wide": "strokeProbeWide",
            "motion-spring-probe": "motionSpringProbe",
            "motion-duration-probe": "motionDurationProbe",
        }
        for name, identifier in expected.items():
            with self.subTest(token=name):
                self.assertRegex(css, r"(?m)^\s*--%s: " % re.escape(name))
                self.assertEqual(keys.get(name), identifier)
        self.assertIn("--motion-spring-probe: spring(3.2, 14, 7.5);", css)
        self.assertIn("--color-probe-alias: var(--color-probe-pair);", css)

    @legit("A key for a token that the source lacks is not generated", "GeneratedTokens.swift", "0 extra keys")
    def test_a_removed_token_leaves_no_key_behind(self):
        work = Work(self)
        work.generate(self)
        removed = work.load()["spacing"]["tokens"][0]["name"]
        self.assertIn(removed, [name for _, name in swift_keys(read_text(work.swift))])

        def remove(data):
            del data["spacing"]["tokens"][0]
        work.mutate(remove)
        work.generate(self)
        self.assertNotIn(removed, [name for _, name in swift_keys(read_text(work.swift))])
        self.assertNotIn("--%s:" % removed, read_text(work.web))


def new_classes():
    return [cls for name, cls in sorted(globals().items()) if isinstance(cls, type)
            and issubclass(cls, unittest.TestCase) and cls.__module__ == __name__ and name != "Legitimation"]


class Legitimation(unittest.TestCase):
    @legit("Every test method of this file carries its legitimation as data", "this file", "all fields set")
    def test_every_test_carries_its_legitimation(self):
        classes = new_classes()
        self.assertTrue(classes)
        for cls in classes:
            for name in unittest.TestLoader().getTestCaseNames(cls):
                with self.subTest(test="%s.%s" % (cls.__name__, name)):
                    data = getattr(getattr(cls, name), "legit", None)
                    self.assertIsInstance(data, dict)
                    self.assertTrue(all(data.get(key) for key in
                                        ("criterion", "where", "threshold", "issue", "when", "who")), data)
                    self.assertRegex(data["issue"], r"#\d+")
                    datetime.date.fromisoformat(data["when"])
                    self.assertIn(data["who"], WHO_VALUES)


if __name__ == "__main__":
    unittest.main(verbosity=1)
