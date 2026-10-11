#!/usr/bin/env python3
"""Tests for the rule list, the tolerations, the queue status and the issue reference of scripts/waechter.py.

Helpers come from scripts/waechter_test.py. Run: python3 scripts/waechter_signals_test.py
"""
import datetime
import os
import re
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from waechter_test import (BAD_MESSAGE, FILLER, GOOD_MESSAGE, TASK_MARKER, TOKEN_DIR, TOOLS_DIR, TRAILER, UMLAUT,
                           WHO_VALUES, GuardCase, TempRepo, assert_legit, commit_file, copy_tools, legit, message_file, new_classes)

SAMPLE = "app/Sources/Core/Sample.swift"
GERMAN = "// %s %s\nlet value = 1\n" % (FILLER, FILLER)
WITH_REFS = "Add the guard\n\nRefs #12\n\n" + TRAILER + "\n"


def day(offset):
    return (datetime.date.today() + datetime.timedelta(days=offset)).isoformat()


def guard_copy(repo, *args):
    command = [sys.executable, os.path.join(repo.dir, "scripts", "waechter.py"), *args]
    proc = subprocess.run(command, cwd=repo.dir, env=dict(repo.env, WAECHTER_STRICT="1"), capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def rule_table(case, repo):
    rc, out = repo.guard("rules")
    case.assertEqual(rc, 0, out)
    table = {}
    for line in out.splitlines():
        fields = [field.strip() for field in line.split(" | ")]
        if re.fullmatch(r"R\d+", fields[0]):
            table.setdefault(fields[0], []).append(fields)
    return table, out


def stage_and_guard(path, content):
    def run(repo):
        repo.stage(path, content)
        return repo.guard("commit", strict=True)
    return run


TRIGGERS = {
    "R1": lambda repo: (repo.git("branch", "probe"), repo.guard("commit"))[1],
    "R2": stage_and_guard("probe.bak", "x\n"),
    "R3": stage_and_guard(SAMPLE, "// %s\n" % UMLAUT),
    "R4": stage_and_guard("scripts/sample.py", "# %s\n" % TASK_MARKER),
    "R5": stage_and_guard(TOKEN_DIR + "View.swift", 'let c = "#FF00AA"\n'),
    "R6": stage_and_guard(TOKEN_DIR + "Long.swift", 'func run() { print("x") }\n'),
    "R7": lambda repo: repo.guard("msg", message_file(repo, BAD_MESSAGE)),
}


class RuleMetadata(GuardCase):
    @legit("The rules command lists id, reason, who, when, origin, scope and threshold per rule", "all rules",
           "R2 2, R6 800, R7 72")
    def test_rules_lists_every_rule_with_all_metadata(self):
        table, out = rule_table(self, self.repo)
        for rule in TRIGGERS:
            with self.subTest(rule=rule):
                self.assertEqual(len(table.get(rule, [])), 1, out)
                fields = table[rule][0]
                self.assertEqual(len(fields), 7, fields)
                self.assertTrue(all(fields), fields)
                self.assertIn(fields[2], WHO_VALUES)
                self.assertRegex(fields[3], r"\d{4}-\d{2}-\d{2}")
                datetime.date.fromisoformat(fields[3])
                self.assertRegex(fields[4], r"#\d+|[\"%s%s]" % (chr(0x201E), chr(0x201C)))
        for rule, number in (("R2", 2), ("R6", 800), ("R7", 72)):
            self.assertRegex(table[rule][0][6], r"\b%d\b" % number)

    @legit("Every rule has a case that triggers it and every rejection names reason, origin and threshold", "all rules",
           "per rule")
    def test_every_rejection_names_reason_origin_and_threshold(self):
        table, out = rule_table(self, self.repo)
        for rule, rows in sorted(table.items()):
            with self.subTest(rule=rule):
                self.assertIn(rule, TRIGGERS, "no rejection case for this rule")
                result = TRIGGERS[rule](TempRepo(self))
                self.assertBlocks(result, rule)
                for text in (rows[0][1], rows[0][4], rows[0][6]):
                    self.assertIn(text, result[1])


class Tolerations(unittest.TestCase):
    def repo_with(self, *lines):
        repo = TempRepo(self)
        copy_tools(repo)
        with open(os.path.join(repo.dir, "scripts", "waechter-woerter.txt"), "a", encoding="utf-8") as handle:
            handle.write("\n[tolerations]\n" + "".join(line + "\n" for line in lines))
        return repo

    def line(self, offset, glob="app/Sources/Core/*", rule="R3", issue=42):
        return "%s | %s | %s | #%d | sample area is open for a while" % (glob, rule, day(offset), issue)

    @legit("A toleration before its end date only warns and shows the remaining days", "toleration glob", "5 days left")
    def test_toleration_before_expiry_only_warns_with_the_remaining_days(self):
        repo = self.repo_with(self.line(5))
        repo.stage(SAMPLE, GERMAN)
        rc, out = guard_copy(repo, "commit")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"(?m)^warn R3 ")
        self.assertRegex(out, r"\b5 days\b")
        repo.git("commit", "-q", "--no-verify", "-m", GOOD_MESSAGE)
        sha = repo.git("rev-parse", "HEAD").stdout.strip()
        rc, out = guard_copy(repo, "push", repo.base, sha, "refs/heads/main")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"(?m)^warn R3 ")

    @legit("A toleration after its end date blocks again", "toleration glob", "end date passed")
    def test_toleration_after_expiry_blocks_again(self):
        repo = self.repo_with(self.line(-2))
        repo.stage(SAMPLE, GERMAN)
        rc, out = guard_copy(repo, "commit")
        self.assertEqual(rc, 1, out)
        self.assertRegex(out, r"(?m)^R3 ")
        self.assertIn("expired", out)

    @legit("A toleration line without a valid date is an error and tolerates nothing", "toleration lines", "date required")
    def test_toleration_line_without_a_valid_date_is_invalid(self):
        glob = "app/Sources/Core/*"
        for line in (glob + " | R3 | #42 | no date", glob + " | R3 | | #42 | empty date", glob + " | R3 | soon | #42 | not a date"):
            with self.subTest(line=line):
                repo = self.repo_with(line)
                repo.stage("plan/new.md", "x\n")
                rc, out = guard_copy(repo, "commit")
                self.assertEqual(rc, 1, out)
                self.assertIn("invalid", out.lower())
                repo.stage(SAMPLE, GERMAN)
                rc, out = guard_copy(repo, "commit")
                self.assertRegex(out, r"(?m)^R3 ")
                self.assertNotRegex(out, r"(?m)^warn R3 ")

    @legit("A toleration covers a whole work area but only its paths and its rule", "toleration glob and rule", "path, rule")
    def test_toleration_covers_only_its_paths_and_rule(self):
        repo = self.repo_with(self.line(5, glob="app/Sources/Area/*"))
        repo.stage("app/Sources/Area/A.swift", GERMAN)
        repo.stage("app/Sources/Area/B.swift", GERMAN.replace("value", "other"))
        self.assertEqual(guard_copy(repo, "commit")[0], 0)
        repo.stage("app/Sources/Other/C.swift", GERMAN.replace("value", "third"))
        rc, out = guard_copy(repo, "commit")
        self.assertEqual(rc, 1, out)
        self.assertRegex(out, r"(?m)^R3 app/Sources/Other/C\.swift")
        other_rule = self.repo_with(self.line(5, rule="R4"))
        other_rule.stage(SAMPLE, GERMAN)
        self.assertRegex(guard_copy(other_rule, "commit")[1], r"(?m)^R3 ")

    @legit("The rules command lists running and expired tolerations", "scripts/waechter-woerter.txt", "state per line")
    def test_rules_lists_running_and_expired_tolerations(self):
        repo = self.repo_with(self.line(5, glob="app/Sources/Run/*", issue=42), self.line(-2, glob="app/Sources/Old/*", issue=43))
        rc, out = guard_copy(repo, "rules")
        self.assertEqual(rc, 0, out)
        lines = [line for line in out.splitlines() if line.startswith("toleration")]
        self.assertEqual(len(lines), 2, out)
        running = next(line for line in lines if "app/Sources/Run/*" in line)
        expired = next(line for line in lines if "app/Sources/Old/*" in line)
        for text in (day(5), "#42", "running"):
            self.assertIn(text, running)
        for text in (day(-2), "#43", "expired"):
            self.assertIn(text, expired)
        self.assertNotIn("expired", running)
        self.assertNotIn("running", expired)


class Queue(GuardCase):
    @legit("The status command shows the waiting commits, the red rule and its reason", "unpushed commits", "2 commits")
    def test_status_shows_the_queue_with_rule_and_reason(self):
        self.repo.make_remote()
        self.repo.git("push", "-q", "-u", "origin", "main")
        commit_file(self.repo, "plan/probe.bak", "x\n")
        commit_file(self.repo, "plan/note.md", "y\n")
        rc, out = self.repo.guard("status")
        self.assertIn(rc, (0, 1), out)
        self.assertIn("waiting commits: 2", out)
        self.assertRegex(out, r"(?m)^R2 plan/probe\.bak")
        self.assertIn(rule_table(self, self.repo)[0]["R2"][0][1], out)
        clean = TempRepo(self)
        clean.make_remote()
        clean.git("push", "-q", "-u", "origin", "main")
        commit_file(clean, "plan/note.md", "y\n")
        rc, out = clean.guard("status")
        self.assertIn(rc, (0, 1), out)
        self.assertIn("waiting commits: 1", out)
        self.assertNotRegex(out, r"(?m)^R\d ")


class IssueReference(GuardCase):
    @legit("A code commit without a Refs line warns, with the line or for material only it stays quiet",
           "app scripts against material folders", "exit 0")
    def test_r7_warns_about_a_missing_issue_reference_for_code_commits(self):
        cases = (("scripts/sample.py", GOOD_MESSAGE, True), (SAMPLE, GOOD_MESSAGE, True),
                 ("scripts/sample.py", WITH_REFS, False), (TOOLS_DIR + "/tool.py", GOOD_MESSAGE, False),
                 ("plan/ernte/data.md", GOOD_MESSAGE, False))
        for path, message, warned in cases:
            with self.subTest(path=path, refs="Refs" in message):
                repo = TempRepo(self)
                repo.stage(path, "let value = 1\n")
                rc, out = repo.guard("msg", message_file(repo, message))
                self.assertEqual(rc, 0, out)
                if warned:
                    self.assertRegex(out, r"(?m)^warn R7 .*Refs #")
                else:
                    self.assertNotRegex(out, r"(?m)^warn ")

    @legit("The push check warns about a code commit without a Refs line", "app scripts", "exit 0")
    def test_push_warns_about_a_missing_issue_reference(self):
        plain = commit_file(self.repo, "scripts/sample.py", "value = 1\n")
        rc, out = self.repo.guard("push", self.repo.base, plain, "refs/heads/main")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"(?m)^warn R7 .*Refs #")
        marked = commit_file(self.repo, "scripts/other.py", "value = 2\n", WITH_REFS)
        rc, out = self.repo.guard("push", plain, marked, "refs/heads/main")
        self.assertEqual(rc, 0, out)
        self.assertNotRegex(out, r"(?m)^warn ")


class LegitimationSignals(unittest.TestCase):
    @legit("Every test method of the signal classes carries its legitimation as data", "this file", "all fields set")
    def test_every_new_test_carries_its_legitimation(self):
        classes = new_classes(__name__, globals())
        self.assertIn(Tolerations, classes)
        assert_legit(self, classes)


if __name__ == "__main__":
    unittest.main(verbosity=1)
