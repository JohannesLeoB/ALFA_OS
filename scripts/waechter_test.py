#!/usr/bin/env python3
"""Tests for scripts/waechter.py and the git hooks.

Every case runs in a temporary git repository below the system temp folder.
German sample text is taken from the word lists, never typed here.
Run: python3 scripts/waechter_test.py
"""
import datetime
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SCRIPT = os.path.join(HERE, "waechter.py")
spec = importlib.util.spec_from_file_location("waechter", SCRIPT)
waechter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(waechter)
WORDS = waechter.Words(os.path.join(HERE, "waechter-woerter.txt"))

FILLER = sorted(WORDS.fillers)[0]
STEM = sorted(WORDS.stems)[0]
TRAILER = WORDS.trailer
UMLAUT = chr(0xE4)
TASK_MARKER = "TO" + "DO"
BRIEF_ID = "B" + "-123"
TOKEN_DIR = WORDS.token_dirs[0]
EXEMPT_MODULE = sorted(WORDS.token_exempt)[0]
GOOD_MESSAGE = "Add the base file\n\n" + TRAILER + "\n"
NOT_STRICT = unittest.skipIf(waechter.STRENG_SPRACHE_META, "language and meta rules are already strict")


def clean_env(home):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(HOME=home, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    return env


class TempRepo:
    """A work repository with a bare remote, both below one temporary folder."""

    def __init__(self, case):
        self.tmp = tempfile.TemporaryDirectory(prefix="waechter-test-")
        case.addCleanup(self.tmp.cleanup)
        self.dir = os.path.join(self.tmp.name, "work")
        self.remote = os.path.join(self.tmp.name, "remote.git")
        self.env = clean_env(self.tmp.name)
        os.mkdir(self.dir)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "commit.gpgsign", "false")
        self.write("plan/base.md", "base\n")
        self.git("add", "plan/base.md")
        self.git("commit", "-q", "--no-verify", "-m", GOOD_MESSAGE)
        self.base = self.git("rev-parse", "HEAD").stdout.strip()

    def git(self, *args, check=True, data=None):
        proc = subprocess.run(["git", *args], cwd=self.dir, env=self.env, capture_output=True, text=True, input=data)
        if check and proc.returncode != 0:
            raise AssertionError("git %s failed: %s" % (" ".join(args), proc.stderr))
        return proc

    def write(self, path, content):
        full = os.path.join(self.dir, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as handle:
            handle.write(content if isinstance(content, bytes) else content.encode("utf-8"))

    def stage(self, path, content):
        self.write(path, content)
        self.git("add", path)

    def commit_message(self, message, name="plan/extra.md"):
        self.write(name, message)
        self.git("add", name)
        self.git("commit", "-q", "--no-verify", "-m", message)
        return self.git("rev-parse", "HEAD").stdout.strip()

    def guard(self, *args, strict=False, extra_env=None):
        env = dict(self.env)
        if strict:
            env["WAECHTER_STRICT"] = "1"
        env.update(extra_env or {})
        proc = subprocess.run([sys.executable, SCRIPT, *args], cwd=self.dir, env=env, capture_output=True, text=True)
        return proc.returncode, proc.stdout + proc.stderr

    def make_remote(self):
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", self.remote], env=self.env, check=True)
        self.git("remote", "add", "origin", self.remote)


class GuardCase(unittest.TestCase):
    def setUp(self):
        self.repo = TempRepo(self)

    def assertBlocks(self, result, rule):
        rc, out = result
        self.assertEqual(rc, 1, out)
        self.assertRegex(out, r"(?m)^%s " % rule)

    def assertPasses(self, result):
        rc, out = result
        self.assertEqual(rc, 0, out)


class R1Branch(GuardCase):
    def test_r1_blocks_commit_with_extra_local_branch(self):
        self.repo.git("branch", "probe")
        self.assertBlocks(self.repo.guard("commit"), "R1")

    def test_r1_blocks_commit_when_head_is_not_main(self):
        self.repo.git("checkout", "-q", "-b", "other")
        self.assertBlocks(self.repo.guard("commit"), "R1")

    def test_r1_passes_commit_on_main_only(self):
        self.assertPasses(self.repo.guard("commit"))

    def test_r1_blocks_push_to_other_ref(self):
        self.assertBlocks(self.repo.guard("push", "0" * 40, self.repo.base, "refs/heads/other"), "R1")

    def test_r1_blocks_ref_delete(self):
        self.assertBlocks(self.repo.guard("push", self.repo.base, "0" * 40, "refs/heads/main"), "R1")

    def test_r1_blocks_force_push(self):
        second = self.repo.commit_message("Add a second file\n\n" + TRAILER + "\n")
        tree = self.repo.git("rev-parse", self.repo.base + "^{tree}").stdout.strip()
        other = self.repo.git("commit-tree", tree, "-m", GOOD_MESSAGE).stdout.strip()
        self.assertBlocks(self.repo.guard("push", second, other, "refs/heads/main"), "R1")

    def test_r1_passes_fast_forward_push(self):
        second = self.repo.commit_message("Add a second file\n\n" + TRAILER + "\n")
        self.assertPasses(self.repo.guard("push", self.repo.base, second, "refs/heads/main"))

    def test_r1_ci_blocks_extra_remote_branch(self):
        self.repo.make_remote()
        self.repo.git("branch", "probe")
        self.repo.git("push", "-q", "origin", "main", "probe")
        self.assertBlocks(self.repo.guard("ci"), "R1")

    def test_r1_ci_passes_with_main_only(self):
        self.repo.make_remote()
        self.repo.git("push", "-q", "origin", "main")
        self.assertPasses(self.repo.guard("ci"))


class R2Sprawl(GuardCase):
    def test_r2_blocks_backup_file(self):
        self.repo.stage("probe.bak", "x\n")
        self.assertBlocks(self.repo.guard("commit"), "R2")

    def test_r2_blocks_copy_name(self):
        self.repo.stage("plan/notes copy.md", "x\n")
        self.assertBlocks(self.repo.guard("commit"), "R2")

    def test_r2_blocks_unknown_root(self):
        self.repo.stage("stuff/a.txt", "x\n")
        self.assertBlocks(self.repo.guard("commit"), "R2")

    def test_r2_blocks_file_over_two_megabytes(self):
        self.repo.stage("plan/big.bin", b"a" * (2 * 1024 * 1024 + 1))
        self.assertBlocks(self.repo.guard("commit"), "R2")

    def test_r2_blocks_identical_files(self):
        self.repo.stage("plan/a.md", "same\n")
        self.repo.stage("plan/b.md", "same\n")
        self.assertBlocks(self.repo.guard("commit"), "R2")

    def test_r2_blocks_ds_store(self):
        self.repo.stage("plan/.DS_Store", "x\n")
        self.assertBlocks(self.repo.guard("commit"), "R2")

    def test_r2_tree_mode_sees_untracked_backup_file(self):
        self.repo.write("probe.bak", "x\n")
        self.assertBlocks(self.repo.guard("baum"), "R2")

    def test_r2_passes_new_file_in_allowed_root(self):
        self.repo.stage("plan/new.md", "new\n")
        self.assertPasses(self.repo.guard("commit"))

    def test_r2_passes_deleting_an_old_file(self):
        self.repo.git("rm", "-q", "plan/base.md")
        self.assertPasses(self.repo.guard("commit"))


class R3Language(GuardCase):
    path = "app/Sources/Core/Sample.swift"

    def test_r3_blocks_umlaut_in_code(self):
        self.repo.stage(self.path, "// %s\nlet value = 1\n" % UMLAUT)
        self.assertBlocks(self.repo.guard("commit", strict=True), "R3")

    def test_r3_blocks_german_filler_word_in_comment(self):
        self.repo.stage(self.path, "// %s %s\nlet value = 1\n" % (FILLER, FILLER))
        self.assertBlocks(self.repo.guard("commit", strict=True), "R3")

    def test_r3_blocks_german_filler_word_in_string(self):
        self.repo.stage(self.path, 'let text = "%s %s"\n' % (FILLER, FILLER))
        self.assertBlocks(self.repo.guard("commit", strict=True), "R3")

    def test_r3_blocks_german_stem_in_name(self):
        self.repo.stage(self.path, "let %sValue = 1\n" % STEM)
        self.assertBlocks(self.repo.guard("commit", strict=True), "R3")

    def test_r3_passes_contract_path(self):
        self.repo.stage(self.path, 'let file = "vertrag/tokens.dunkel.json"\n')
        self.assertPasses(self.repo.guard("commit", strict=True))

    def test_r3_passes_exchange_field_name(self):
        self.repo.stage(self.path, 'let key = "von"\n')
        self.assertPasses(self.repo.guard("commit", strict=True))

    def test_r3_passes_english_code(self):
        self.repo.stage(self.path, "// Return the width of the frame.\nlet frameWidth = 1\n")
        self.assertPasses(self.repo.guard("commit", strict=True))

    def test_r3_passes_fixture_and_plan_text(self):
        self.repo.stage("app/Tests/Fixtures/Sample.swift", "// %s\n" % UMLAUT)
        self.repo.stage("plan/note.md", "%s %s\n" % (UMLAUT, FILLER))
        self.assertPasses(self.repo.guard("commit", strict=True))

    @NOT_STRICT
    def test_r3_only_warns_while_the_switch_is_off(self):
        self.repo.stage(self.path, "// %s\nlet value = 1\n" % UMLAUT)
        rc, out = self.repo.guard("commit")
        self.assertEqual(rc, 0, out)
        self.assertIn("warn R3", out)


class R4Meta(GuardCase):
    path = "scripts/sample.py"

    def test_r4_blocks_task_marker(self):
        self.repo.stage(self.path, "# %s fix this\n" % TASK_MARKER)
        self.assertBlocks(self.repo.guard("commit", strict=True), "R4")

    def test_r4_blocks_work_item_reference(self):
        self.repo.stage(self.path, "# see %s\n" % BRIEF_ID)
        self.assertBlocks(self.repo.guard("commit", strict=True), "R4")

    def test_r4_blocks_meta_word_in_swift_string(self):
        word = sorted(WORDS.meta_words)[0]
        self.repo.stage("app/Sources/Core/Sample.swift", 'let label = "%s"\n' % word)
        self.assertBlocks(self.repo.guard("commit", strict=True), "R4")

    def test_r4_passes_plain_english_comment(self):
        self.repo.stage(self.path, "# Return the first item.\n")
        self.assertPasses(self.repo.guard("commit", strict=True))

    @NOT_STRICT
    def test_r4_only_warns_while_the_switch_is_off(self):
        self.repo.stage(self.path, "# %s\n" % TASK_MARKER)
        rc, out = self.repo.guard("commit")
        self.assertEqual(rc, 0, out)
        self.assertIn("warn R4", out)


class R5Tokens(GuardCase):
    path = TOKEN_DIR + "View.swift"

    def blocked(self, code):
        self.repo.stage(self.path, code)
        self.assertBlocks(self.repo.guard("commit"), "R5")

    def test_r5_blocks_hex_colour(self):
        self.blocked('let c = "#FF00AA"\n')

    def test_r5_blocks_colour_initialiser(self):
        self.blocked("let c = Color(red: 1, green: 0, blue: 0)\n")

    def test_r5_blocks_named_colour(self):
        self.blocked("let c = Color.red\n")

    def test_r5_blocks_system_font_size(self):
        self.blocked("let f = Font.system(size: 12)\n")

    def test_r5_blocks_number_in_padding(self):
        self.blocked("let v = Text(x).padding(8)\n")

    def test_r5_blocks_number_in_edge_padding(self):
        self.blocked("let v = Text(x).padding(.horizontal, 8)\n")

    def test_r5_blocks_number_in_spacing(self):
        self.blocked("let v = VStack(spacing: 8) { }\n")

    def test_r5_blocks_number_in_corner_radius(self):
        self.blocked("let v = RoundedRectangle(cornerRadius: 6)\n")

    def test_r5_passes_theme_values_and_zero_spacing(self):
        self.repo.stage(self.path, "let a = VStack(spacing: 0) { }\n"
                        "let b = Text(x).padding(theme.space(.s2))\n"
                        "// padding(8) in a comment\n"
                        'let c = "padding(8)"\n')
        self.assertPasses(self.repo.guard("commit"))

    def test_r5_passes_in_exempt_module(self):
        self.repo.stage("app/Sources/%s/Raw.swift" % EXEMPT_MODULE, 'let c = "#FF00AA"\n')
        self.assertPasses(self.repo.guard("commit"))

    def test_r5_passes_in_tests(self):
        self.repo.stage("app/Tests/CoreTests/Raw.swift", 'let c = "#FF00AA"\n')
        self.assertPasses(self.repo.guard("commit"))


class R6Drift(GuardCase):
    path = TOKEN_DIR + "Long.swift"

    @staticmethod
    def lines(count):
        return "".join("let value%d = %d\n" % (i, i) for i in range(count))

    def test_r6_blocks_file_over_800_lines(self):
        self.repo.stage(self.path, self.lines(801))
        self.assertBlocks(self.repo.guard("commit"), "R6")

    def test_r6_passes_file_with_800_lines(self):
        self.repo.stage(self.path, self.lines(800))
        self.assertPasses(self.repo.guard("commit"))

    def test_r6_blocks_print_call(self):
        self.repo.stage(self.path, 'func run() { print("x") }\n')
        self.assertBlocks(self.repo.guard("commit"), "R6")

    def test_r6_passes_print_in_comment_string_and_tests(self):
        self.repo.stage(self.path, '// print("x")\nlet text = "print(1)"\nlet value = blueprint(2)\n')
        self.repo.stage("app/Tests/CoreTests/Print.swift", 'func run() { print("x") }\n')
        self.assertPasses(self.repo.guard("commit"))


class R7Message(GuardCase):
    def message(self, text):
        path = os.path.join(self.repo.dir, "MSG")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        return self.repo.guard("msg", path)

    def test_r7_passes_good_message_with_body(self):
        self.assertPasses(self.message(
            "Add the guard\n\nThe hook checks the staged files.\n- It runs fast.\n\n" + TRAILER + "\n"))

    def test_r7_blocks_long_subject(self):
        self.assertBlocks(self.message("Add " + "x" * 80 + "\n\n" + TRAILER + "\n"), "R7")

    def test_r7_blocks_period_at_the_end(self):
        self.assertBlocks(self.message("Add the guard.\n\n" + TRAILER + "\n"), "R7")

    def test_r7_blocks_subject_without_imperative_verb(self):
        self.assertBlocks(self.message("Added the guard\n\n" + TRAILER + "\n"), "R7")

    def test_r7_blocks_german_text(self):
        self.assertBlocks(self.message("Add the guard\n\n%s %s\n\n%s\n" % (FILLER, FILLER, TRAILER)), "R7")

    def test_r7_blocks_umlaut(self):
        self.assertBlocks(self.message("Add the guard %s\n\n%s\n" % (UMLAUT, TRAILER)), "R7")

    def test_r7_blocks_long_sentence(self):
        sentence = " ".join(["word"] * 21) + "."
        self.assertBlocks(self.message("Add the guard\n\n%s\n\n%s\n" % (sentence, TRAILER)), "R7")

    def test_r7_blocks_missing_trailer(self):
        self.assertBlocks(self.message("Add the guard\n"), "R7")

    def test_r7_blocks_trailer_that_is_not_last(self):
        self.assertBlocks(self.message("Add the guard\n\n" + TRAILER + "\n\nMore text.\n"), "R7")

    def test_r7_blocks_co_author_line(self):
        self.assertBlocks(self.message("Add the guard\n\nCo-Authored-By: A <a@example.com>\n\n" + TRAILER + "\n"), "R7")

    def test_r7_push_checks_every_new_commit(self):
        bad = self.repo.commit_message("Added a file\n\n" + TRAILER + "\n")
        self.assertBlocks(self.repo.guard("push", self.repo.base, bad, "refs/heads/main"), "R7")

    def test_r7_ci_checks_commits_since_the_base(self):
        self.repo.commit_message("Added a file\n\n" + TRAILER + "\n")
        self.assertBlocks(self.repo.guard("ci", extra_env={"WAECHTER_FROM": self.repo.base}), "R7")


class Segments(unittest.TestCase):
    def kinds(self, text):
        return [(k, text[a:b]) for k, a, b in waechter.swift_segments(text) if k != "code"]

    def test_nested_interpolation_keeps_inner_text_as_code(self):
        text = 'let a = "x \\(b ? "y" : "z") w" // c'
        self.assertEqual(self.kinds(text), [
            ("string", "x "), ("string", "y"), ("string", "z"), ("string", " w"), ("comment", "// c")])

    def test_quote_in_comment_does_not_open_a_string(self):
        self.assertEqual(self.kinds('// it"s\nlet a = 1\n'), [("comment", '// it"s')])

    def test_words_file_has_the_lists_the_rules_need(self):
        for name in ("fillers", "stems", "meta_words", "verbs", "roots_dirs", "code_dirs", "token_dirs"):
            self.assertTrue(getattr(WORDS, name), name)
        self.assertTrue(WORDS.trailer)
        self.assertIn("Add", WORDS.verbs)


class HookCase(unittest.TestCase):
    """The real hook files in a temporary repository, driven by real git commands."""

    def setUp(self):
        self.repo = TempRepo(self)
        os.makedirs(os.path.join(self.repo.dir, "scripts"))
        shutil.copytree(os.path.join(REPO, ".githooks"), os.path.join(self.repo.dir, ".githooks"))
        for name in ("waechter.py", "waechter-woerter.txt"):
            shutil.copy2(os.path.join(HERE, name), os.path.join(self.repo.dir, "scripts", name))
        stub_test_files(self.repo, "import sys\nsys.exit(0)\n")
        self.repo.git("config", "core.hooksPath", ".githooks")
        self.repo.make_remote()

    def stub_check(self, code):
        path = os.path.join(self.repo.dir, "scripts", "pruefen.sh")
        with open(path, "w") as handle:
            handle.write("#!/bin/sh\nexit %d\n" % code)

    def test_hook_pre_commit_rejects_backup_file(self):
        self.repo.write("probe.bak", "x\n")
        self.repo.git("add", "probe.bak")
        proc = self.repo.git("commit", "-q", "-m", GOOD_MESSAGE, check=False)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(self.repo.git("rev-parse", "HEAD").stdout.strip(), self.repo.base)

    def test_hook_commit_msg_rejects_bad_message(self):
        self.repo.write("plan/new.md", "x\n")
        self.repo.git("add", "plan/new.md")
        proc = self.repo.git("commit", "-q", "-m", "added a file", check=False)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("R7", proc.stdout + proc.stderr)

    def test_hook_accepts_a_good_commit(self):
        self.repo.write("plan/new.md", "x\n")
        self.repo.git("add", "plan/new.md")
        self.repo.git("commit", "-q", "-m", "Add a plan file\n\n" + TRAILER)
        self.assertNotEqual(self.repo.git("rev-parse", "HEAD").stdout.strip(), self.repo.base)

    def test_hook_pre_push_rejects_other_branch(self):
        self.stub_check(0)
        proc = self.repo.git("push", "-q", "origin", "HEAD:refs/heads/probe", check=False)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("R1", proc.stdout + proc.stderr)

    def test_hook_pre_push_runs_the_full_check(self):
        commit_file(self.repo, "app/Sources/Core/Sample.swift", "let value = 1\n")
        self.stub_check(1)
        self.assertNotEqual(self.repo.git("push", "-q", "origin", "main", check=False).returncode, 0)
        self.stub_check(0)
        self.assertEqual(self.repo.git("push", "-q", "origin", "main", check=False).returncode, 0)


ISSUE, WHEN, WHO = "#10", "2026-10-11", "Ch" + "ef"
WHO_VALUES = ("Jo" + "hannes", WHO)
OLD_CLASSES = ("GuardCase", "R1Branch", "R2Sprawl", "R3Language", "R4Meta", "R5Tokens", "R6Drift", "R7Message",
               "Segments", "HookCase")
TOOLS_DIR = "plan/werk" + "zeuge"
MATERIAL_DIRS = ("plan/ernte", TOOLS_DIR, "gestaltung/entwuerfe", "plan/gates")
MATERIAL = " ".join(MATERIAL_DIRS)
NEW_VERBS = ("Rebuild", "Import", "Draft", "Generate", "Publish", "Migrate")
BAD_MESSAGE = "Added the harvest notes\n\n" + TRAILER + "\n"
GERMAN_SCRIPT = "# %s %s\n%s_value = 1\n# %s\n" % (FILLER, FILLER, STEM, UMLAUT)


def legit(criterion, where, threshold="none"):
    def mark(test):
        test.legit = dict(criterion=criterion, where=where, threshold=threshold, issue=ISSUE, when=WHEN, who=WHO)
        return test
    return mark


def copy_tools(repo, hooks=False):
    shutil.copytree(HERE, os.path.join(repo.dir, "scripts"), dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("__pycache__", "*_test.py"))
    if hooks:
        shutil.copytree(os.path.join(REPO, ".githooks"), os.path.join(repo.dir, ".githooks"))


def stub_test_files(repo, code):
    for name in os.listdir(HERE):
        if name.endswith("_test.py"):
            repo.write("scripts/" + name, code)


def message_file(repo, text):
    path = os.path.join(repo.dir, "MSG")
    Path(path).write_text(text, encoding="utf-8")
    return path


def commit_file(repo, path, content, message=GOOD_MESSAGE):
    repo.stage(path, content)
    repo.git("commit", "-q", "--no-verify", "-m", message)
    return repo.git("rev-parse", "HEAD").stdout.strip()


def nested_repo(repo, folder):
    inner = os.path.join(repo.dir, folder, "inner")
    os.makedirs(inner)
    for args in (("init", "-q", "-b", "main"), ("-c", "user.name=T", "-c", "user.email=t@example.com", "commit", "-q",
                                                "--allow-empty", "-m", "x")):
        subprocess.run(["git", *args], cwd=inner, env=repo.env, check=True, capture_output=True)
    repo.git("add", folder + "/inner")


class MaterialTrack(GuardCase):
    @legit("A German script of any length passes in material folders and is rejected in scripts", MATERIAL, "800 lines")
    def test_tools_folder_takes_a_long_german_script_and_scripts_folder_rejects_it(self):
        script = GERMAN_SCRIPT + "".join("v%d = %d\n" % (i, i) for i in range(801))
        for index, folder in enumerate(MATERIAL_DIRS):
            self.repo.stage("%s/tool%d.py" % (folder, index), "# %d\n" % index + script)
        self.assertPasses(self.repo.guard("commit", strict=True))
        other = TempRepo(self)
        other.stage("scripts/tool.py", script)
        self.assertBlocks(other.guard("commit", strict=True), "R3")

    @legit("Material folders keep size, nested git, duplicate and blocked-name checks by whole word", MATERIAL, "2 MB")
    def test_material_folders_keep_the_hygiene_checks_and_allow_longer_names(self):
        for index, folder in enumerate(MATERIAL_DIRS):
            self.repo.stage(folder + "/big.bin", bytes([index]) + b"a" * (2 * 1024 * 1024))
            self.repo.stage(folder + "/a.md", "same%d\n" % index)
            self.repo.stage(folder + "/b.md", "same%d\n" % index)
            self.repo.stage(folder + "/notes_old.md", "old%d\n" % index)
            nested_repo(self.repo, folder)
        rc, out = self.repo.guard("commit")
        self.assertEqual(rc, 1, out)
        for folder in MATERIAL_DIRS:
            for what in ("/big.bin", "/b.md", "/notes_old.md", "/inner"):
                with self.subTest(folder=folder, path=what):
                    self.assertRegex(out, r"(?m)^R2 %s: " % re.escape(folder + what))
        other = TempRepo(self)
        for index, folder in enumerate(MATERIAL_DIRS):
            other.stage(folder + "/copywriting-notes.md", "x%d\n" % index)
        self.assertPasses(other.guard("commit"))


class R2Words(GuardCase):
    @legit("The name block matches whole words only", "all folders", "whole word")
    def test_r2_blocks_whole_words_and_allows_longer_names(self):
        blocked = ("plan/notes_old.md", "plan/notes_alt.md", "plan/copy.md", "plan/kopie.md", "plan/notes copy.md",
                   "plan/x.bak", "plan/x.orig", "plan/x.tmp", "plan/draft~")
        for number, path in enumerate(blocked):
            self.repo.stage(path, "x%d\n" % number)
        rc, out = self.repo.guard("commit")
        self.assertEqual(rc, 1, out)
        for path in blocked:
            with self.subTest(blocked=path):
                self.assertRegex(out, r"(?m)^R2 %s: blocked file name" % re.escape(path))
        other = TempRepo(self)
        other.stage("app/Sources/Core/Copyable.swift", "struct Copyable {}\n")
        other.stage("plan/copywriting-notes.md", "notes\n")
        self.assertPasses(other.guard("commit"))


class R7Extended(GuardCase):
    def msg(self, text):
        return self.repo.guard("msg", message_file(self.repo, text))

    @legit("The verb list holds the common verbs", "commit subject", "6 added verbs")
    def test_r7_accepts_the_extended_verbs(self):
        for verb in NEW_VERBS:
            with self.subTest(verb=verb):
                self.assertPasses(self.msg("%s the harvest index\n\n%s\n" % (verb, TRAILER)))

    @legit("A rejected subject names the allowed verbs", "commit subject", "every listed verb")
    def test_r7_rejection_lists_the_allowed_verbs(self):
        rc, out = self.msg(BAD_MESSAGE)
        self.assertEqual(rc, 1, out)
        missing = [v for v in sorted(WORDS.verbs | set(NEW_VERBS)) if not re.search(r"\b%s\b" % v, out)]
        self.assertEqual(missing, [], out)

    @legit("A bad verb only warns when the commit touches material folders only", MATERIAL, "exit 0 against exit 1")
    def test_r7_warns_only_for_commits_that_touch_material_folders_only(self):
        cases = ((["plan/ernte/data.md"], 0), ([TOOLS_DIR + "/tool.py", "plan/gates/note.md"], 0),
                 (["plan/ernte/data.md", "scripts/sample.py"], 1), (["scripts/sample.py"], 1), (["plan/notes.md"], 1))
        for staged, expected in cases:
            with self.subTest(staged=staged):
                repo = TempRepo(self)
                for number, path in enumerate(staged):
                    repo.stage(path, "value%d = 1\n" % number)
                rc, out = repo.guard("msg", message_file(repo, BAD_MESSAGE))
                self.assertEqual(rc, expected, out)
                self.assertRegex(out, r"(?m)^%sR7 " % ("warn " if expected == 0 else ""))

    @legit("The push check treats material-only commits with a bad verb as warnings", MATERIAL, "exit 0 against exit 1")
    def test_r7_push_warns_only_for_material_only_commits(self):
        material = commit_file(self.repo, "plan/ernte/data.md", "x\n", BAD_MESSAGE)
        code = commit_file(self.repo, "scripts/sample.py", "value = 1\n", BAD_MESSAGE)
        rc, out = self.repo.guard("push", self.repo.base, material, "refs/heads/main")
        self.assertEqual(rc, 0, out)
        self.assertIn("warn R7", out)
        self.assertBlocks(self.repo.guard("push", material, code, "refs/heads/main"), "R7")


class HookCommits(unittest.TestCase):
    @legit("The commit hooks let a material-only commit through with a warning and reject a code commit with the verbs",
           MATERIAL + " scripts", "exit 0 against exit 1")
    def test_hook_commit_with_a_bad_verb_depends_on_the_touched_folders(self):
        repo = TempRepo(self)
        copy_tools(repo, hooks=True)
        repo.git("config", "core.hooksPath", ".githooks")
        for path, content in (("plan/ernte/data.md", "x\n"), ("scripts/sample.py", "value = 1\n")):
            repo.stage(path, content)
            proc = repo.git("commit", "-q", "-F", "-", "--", path, check=False, data=BAD_MESSAGE)
            out = proc.stdout + proc.stderr
            if path.startswith("plan/"):
                self.assertEqual(proc.returncode, 0, out)
                self.assertIn("warn R7", out)
            else:
                self.assertNotEqual(proc.returncode, 0, out)
                for verb in NEW_VERBS:
                    self.assertRegex(out, r"\b%s\b" % verb)


class PrePush(unittest.TestCase):
    CHECK = '#!/bin/sh\necho "offline=$ALFACOLOR_TEST_OFFLINE" >> "$STUB_FULL_MARK"\n'
    TESTS = ("import os\nimport unittest\nopen(os.environ['STUB_TESTS_MARK'], 'a').write(os.path.basename(__file__) + '\\n')\n"
             "class Stub(unittest.TestCase):\n    def test_stub(self):\n        pass\n")

    def setUp(self):
        self.repo = TempRepo(self)
        self.repo.env.pop("ALFACOLOR_TEST_OFFLINE", None)
        self.marks = {name: os.path.join(self.repo.tmp.name, name + ".txt") for name in ("full", "tests")}
        self.repo.env["STUB_FULL_MARK"] = self.marks["full"]
        self.repo.env["STUB_TESTS_MARK"] = self.marks["tests"]
        copy_tools(self.repo, hooks=True)
        self.repo.write("scripts/pruefen.sh", self.CHECK)
        os.chmod(os.path.join(self.repo.dir, "scripts", "pruefen.sh"), 0o755)
        stub_test_files(self.repo, self.TESTS)
        self.repo.make_remote()
        self.repo.git("add", "scripts/pruefen.sh")
        self.repo.git("commit", "-q", "--no-verify", "-m", GOOD_MESSAGE)
        self.repo.git("push", "-q", "--no-verify", "origin", "main")
        self.repo.git("config", "core.hooksPath", ".githooks")
        self.count = 0

    def push(self, *paths):
        for mark in self.marks.values():
            Path(mark).unlink(missing_ok=True)
        for path in paths:
            self.count += 1
            content = self.CHECK + ":\n" if path == "scripts/pruefen.sh" else "let value%d = %d\n" % (self.count, self.count)
            commit_file(self.repo, path, content, "Add a file\n\n" + TRAILER)
        proc = self.repo.git("push", "-q", "origin", "main", check=False)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def marked(self, name):
        path = Path(self.marks[name])
        return path.read_text().split() if path.exists() else []

    @legit("A push with text changes only does not start the full check", "plan konzept plan/ernte", "no full check")
    def test_text_only_push_skips_the_full_check(self):
        for path in ("plan/note.md", "konzept/idea.md", "plan/ernte/data.tsv"):
            with self.subTest(path=path):
                self.push(path)
                self.assertEqual(self.marked("full"), [])

    @legit("A push touching app, package or the check script runs the full check offline", "app ALFAcolor pruefen.sh",
           "ALFACOLOR_TEST_OFFLINE=1")
    def test_code_push_runs_the_full_check_with_the_offline_variable(self):
        cases = (("app/Sources/Core/Sample.swift",), ("ALFAcolor/App/Sample.swift",), ("app/Package.swift",),
                 ("scripts/pruefen.sh",), ("plan/note.md", "app/Sources/Core/Other.swift"))
        for paths in cases:
            with self.subTest(paths=paths):
                self.push(*paths)
                self.assertEqual(self.marked("full"), ["offline=1"])

    @legit("Every push runs the guard tests", "all pushes", "once per push")
    def test_every_push_runs_the_guard_tests(self):
        for path in ("plan/note.md", "app/Sources/Core/Sample.swift"):
            with self.subTest(path=path):
                self.push(path)
                self.assertEqual(self.marked("tests").count("waechter_test.py"), 1)


class SetupHooks(unittest.TestCase):
    def setUp(self):
        self.repo = TempRepo(self)
        copy_tools(self.repo, hooks=True)
        self.repo.git("add", "-A")
        self.repo.git("commit", "-q", "--no-verify", "-m", GOOD_MESSAGE)
        self.clone = os.path.join(self.repo.tmp.name, "clone")
        subprocess.run(["git", "clone", "-q", self.repo.dir, self.clone], env=self.repo.env, check=True)
        for key, value in (("user.name", "Test"), ("user.email", "test@example.com"), ("commit.gpgsign", "false")):
            self.run_in("git", "config", key, value)

    def run_in(self, *command, cwd=None):
        return subprocess.run(command, cwd=cwd or self.clone, env=self.repo.env, capture_output=True, text=True)

    def hooks_path(self):
        return self.run_in("git", "config", "--get", "core.hooksPath")

    @legit("A fresh clone has active hooks after the setup script", "scripts/setup-hooks.sh", "core.hooksPath")
    def test_setup_script_activates_the_hooks_of_a_fresh_clone(self):
        self.assertNotEqual(self.hooks_path().returncode, 0)
        done = self.run_in("bash", "scripts/setup-hooks.sh")
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertEqual(self.hooks_path().stdout.strip(), ".githooks")
        Path(self.clone, "plan", "new.md").write_text("x\n")
        self.run_in("git", "add", "plan/new.md")
        proc = self.run_in("git", "commit", "-q", "-m", "added a file")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("R7", proc.stdout + proc.stderr)

    @legit("The setup script works from a subfolder and when run twice", "scripts/setup-hooks.sh", "exit 0")
    def test_setup_script_runs_from_a_subfolder_and_twice(self):
        for _ in range(2):
            done = self.run_in("bash", "../scripts/setup-hooks.sh", cwd=os.path.join(self.clone, "plan"))
            self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertEqual(self.hooks_path().stdout.strip(), ".githooks")


def new_classes(module, namespace):
    return [cls for name, cls in sorted(namespace.items()) if isinstance(cls, type)
            and issubclass(cls, unittest.TestCase) and cls.__module__ == module and name not in OLD_CLASSES]


def assert_legit(case, classes):
    for cls in classes:
        for name in unittest.TestLoader().getTestCaseNames(cls):
            with case.subTest(test="%s.%s" % (cls.__name__, name)):
                data = getattr(getattr(cls, name), "legit", None)
                case.assertIsInstance(data, dict)
                case.assertTrue(all(data.get(key) for key in ("criterion", "where", "threshold", "issue", "when", "who")), data)
                case.assertRegex(data["issue"], r"#\d+")
                datetime.date.fromisoformat(data["when"])
                case.assertIn(data["who"], WHO_VALUES)


class Legitimation(unittest.TestCase):
    @legit("Every test method of the new classes carries its legitimation as data", "new test classes", "all fields set")
    def test_every_new_test_carries_its_legitimation(self):
        classes = new_classes(__name__, globals())
        self.assertIn(MaterialTrack, classes)
        assert_legit(self, classes)


if __name__ == "__main__":
    unittest.main(verbosity=1)
