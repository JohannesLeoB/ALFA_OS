#!/usr/bin/env python3
"""Tests for scripts/vertrag_aus_kanon.py: the contract is read from the canon, twice the same."""
import filecmp
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import vertrag_aus_kanon as script  # noqa: E402

ROOT = os.path.dirname(HERE)
KANON = os.path.join(ROOT, "gestaltung", "kanon")
VERTRAG = os.path.join(ROOT, "gestaltung", "vertrag")


def load(folder, name):
    with open(os.path.join(folder, name), encoding="utf-8") as handle:
        return json.load(handle)


def leaf(tree, *path):
    node = tree
    for part in path:
        node = node[part]
    return node


class ContractFromCanon(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.light = load(VERTRAG, "tokens.json")
        cls.dark = load(VERTRAG, "tokens.dunkel.json")

    def test_second_run_changes_nothing(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            script.main(["--kanon", KANON, "--target", first, "--manifest", ""])
            script.main(["--kanon", KANON, "--target", second, "--manifest", ""])
            for name in ("tokens.json", "tokens.dunkel.json"):
                self.assertTrue(filecmp.cmp(os.path.join(first, name), os.path.join(second, name), shallow=False))

    def test_committed_contract_is_the_output(self):
        with tempfile.TemporaryDirectory() as out:
            script.main(["--kanon", KANON, "--target", out, "--manifest", ""])
            for name in ("tokens.json", "tokens.dunkel.json"):
                self.assertTrue(filecmp.cmp(os.path.join(out, name), os.path.join(VERTRAG, name), shallow=False))

    def test_accent_is_coral_in_both_files(self):
        self.assertEqual(leaf(self.light, "color", "akzent", "$value")["hex"], "#F95C4B")
        self.assertEqual(leaf(self.light, "color", "koralle", "$value")["hex"], "#F95C4B")
        # The dark file names only the differing leaves, so coral is absent there and keeps the light value.
        self.assertNotIn("koralle", self.dark.get("color", {}))
        self.assertNotIn("akzent", self.dark.get("color", {}))

    def test_space_scale_reaches_64(self):
        self.assertEqual(leaf(self.light, "space", "s7", "$value")["value"], 48)
        self.assertEqual(leaf(self.light, "space", "s8", "$value")["value"], 64)

    def test_square_radii_and_pill(self):
        self.assertEqual(leaf(self.light, "radius", "s", "$value")["value"], 0)
        self.assertEqual(leaf(self.light, "radius", "m", "$value")["value"], 0)
        self.assertEqual(leaf(self.light, "radius", "l", "$value")["value"], 999)

    def test_ten_text_styles_with_family_size_weight(self):
        styles = ["zone", "titel", "abschnitt", "kopf", "lead", "lesen", "fliesstext", "bedienung",
                  "beschriftung", "quelltext"]
        for style in styles:
            with self.subTest(style=style):
                node = leaf(self.light, "text", style)
                self.assertIn(node["familie"]["$value"][0], ["System Display", "System Text", "Mono"])
                self.assertIn("unit", node["groesse"]["$value"])
                self.assertIsInstance(node["gewicht"]["$value"], int)
        self.assertEqual(leaf(self.light, "text", "zone", "gewicht", "$value"), 200)
        self.assertEqual(leaf(self.light, "text", "zone", "groesse", "$value")["value"], 64)

    def test_no_references_left(self):
        for tree in (self.light, self.dark):
            text = json.dumps(tree)
            self.assertNotIn("$ref", text)
            self.assertNotIn("{koralle}", text)

    def test_glass_and_shadow_are_split(self):
        self.assertEqual(leaf(self.light, "glas", "saettigung", "$value"), 1.8)
        self.assertEqual(leaf(self.light, "shadow", "schatten-glas", "innen", "unschaerfe", "$value")["value"], 0)
        self.assertEqual(leaf(self.light, "shadow", "schatten-karte", "aussen", "unschaerfe", "$value")["value"], 32)

    def test_dark_file_names_only_differences(self):
        self.assertIn("grund", self.dark["color"])
        self.assertNotIn("zone-stein", self.dark.get("color", {}))


if __name__ == "__main__":
    unittest.main()
