import unittest

from drawer import (RUNNERS, depth_requirement, legrabox_parts, select_nominal_length,
                    wooden_drawer)


class WoodenDrawerTests(unittest.TestCase):
    def test_movento_standard_base_cabinet(self):
        parts = wooden_drawer("blum_movento_760h", 562, 500, 12)
        self.assertEqual(parts["drawer_inside_width"].mm, 520)
        self.assertEqual(parts["drawer_inside_width"].tolerance_mm, (-1.5, 0.0))
        self.assertEqual(parts["drawer_length"].mm, 490)
        self.assertEqual(parts["drawer_outside_width"].mm, 544)
        self.assertEqual(parts["drawer_outside_width"].evidence, "interpretation")
        self.assertEqual(parts["depth_requirement"].mm, 503)

    def test_tandem_19_uses_larger_deduction(self):
        parts = wooden_drawer("blum_tandem_560f", 562, 500, 18)
        self.assertEqual(parts["drawer_inside_width"].mm, 513)
        self.assertEqual(parts["drawer_outside_width"].mm, 549)

    def test_side_thickness_outside_range_fails(self):
        with self.assertRaises(ValueError):
            wooden_drawer("blum_tandem_560h", 562, 500, 18)
        with self.assertRaises(ValueError):
            wooden_drawer("blum_tandem_560f", 562, 500, 15)
        with self.assertRaises(ValueError):
            wooden_drawer("blum_movento_760h", 562, 500, 19)

    def test_unknown_nominal_length_fails(self):
        with self.assertRaises(ValueError):
            wooden_drawer("blum_movento_760h", 562, 510, 12)


class DepthTests(unittest.TestCase):
    def test_extras_add_up(self):
        self.assertEqual(depth_requirement("blum_movento_760h", 500, ("side_stabilisation",)).mm, 515)
        self.assertEqual(depth_requirement("blum_tandem_560h", 500, ("posistop",)).mm, 505)

    def test_inner_drawer(self):
        self.assertEqual(depth_requirement("blum_movento_760h", 500, inner_drawer_front_mm=19).mm, 522)
        self.assertEqual(depth_requirement("blum_movento_760h", 500, inner_drawer_front_mm=19,
                                           opening="push_to_open").mm, 526)

    def test_select_nominal_length(self):
        self.assertEqual(select_nominal_length("blum_movento_760h", 520).mm, 500)
        self.assertEqual(select_nominal_length("blum_movento_760h", 520, ("side_stabilisation",)).mm, 500)
        self.assertEqual(select_nominal_length("blum_movento_760h", 503).mm, 500)
        self.assertEqual(select_nominal_length("blum_movento_760h", 502).mm, 480)
        with self.assertRaises(ValueError):
            select_nominal_length("blum_movento_766h", 400)


class LegraboxTests(unittest.TestCase):
    def test_wood_back(self):
        parts = legrabox_parts("M", 562, 500)
        self.assertEqual(parts["bottom_width"].mm, 527)
        self.assertEqual(parts["bottom_length"].mm, 490)
        self.assertEqual(parts["back_width"].mm, 524)
        self.assertEqual(parts["back_height"].mm, 63)
        self.assertEqual(parts["bottom_width"].evidence, "derived")

    def test_steel_back(self):
        parts = legrabox_parts("M", 562, 500, back="steel")
        self.assertEqual(parts["bottom_length"].mm, 479)
        self.assertNotIn("back_width", parts)

    def test_f_has_no_wood_back_height(self):
        self.assertNotIn("back_height", legrabox_parts("F", 562, 500))


class DataTests(unittest.TestCase):
    def test_every_runner_has_sorted_lengths_and_sources(self):
        for item in RUNNERS.values():
            self.assertEqual(list(item.nominal_lengths_mm), sorted(item.nominal_lengths_mm))
            self.assertTrue(item.sources)


if __name__ == "__main__":
    unittest.main()
