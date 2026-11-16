import json
import unittest

import helpers
from art_pipeline import validate_sheet as vs
from art_pipeline.common import PipelineError, sha256_file


def codes(report, severity=None):
    return sorted(i["code"] for i in report["issues"] if severity in (None, i["severity"]))


class SingleSheet(helpers.TempCase):
    def test_valid_character_view_passes_with_measurements(self):
        path = helpers.view_sheet(self.tmp / "south.png", idle_height=60)
        report = vs.validate_sheet(path, vs.make_spec("character_view", "south"))
        self.assertEqual(report["status"], "pass", report["issues"])
        self.assertEqual(report["measurements"]["sprite_count"], 16)
        self.assertEqual(report["measurements"]["idle_height_px"], 60.0)
        self.assertEqual(report["sheet"]["sha256"], sha256_file(path))
        self.assertEqual(report["schema"], "ragrpg_art_validation_report_v1")

    def test_empty_cell_is_an_error_with_the_cell_index(self):
        path = helpers.view_sheet(self.tmp / "s.png", empty_cells=(5,))
        report = vs.validate_sheet(path, vs.make_spec("character_view"))
        self.assertEqual(report["status"], "fail")
        issue = next(i for i in report["issues"] if i["code"] == "empty_cell")
        self.assertEqual(issue["details"]["cells"], [5])
        self.assertEqual(issue["severity"], "error")

    def test_content_on_the_cell_border_and_missing_gutter_are_reported(self):
        path = helpers.view_sheet(self.tmp / "s.png", overflow={14: 12})
        report = vs.validate_sheet(path, vs.make_spec("character_view"))
        self.assertIn("touches_cell_edge", codes(report, "error"))
        self.assertIn("no_gutter_band", codes(report, "error"))
        band = next(i for i in report["issues"] if i["code"] == "no_gutter_band")["details"]["boundaries"][0]
        self.assertEqual((band["axis"], band["row"]), ("vertical", 4))
        self.assertIsNotNone(band["suggested_crop_override"])

    def test_suggested_crop_override_makes_the_sheet_pass_when_applied(self):
        path = helpers.view_sheet(self.tmp / "s.png", overflow={14: 12})
        first = vs.validate_sheet(path, vs.make_spec("character_view"))
        band = next(i for i in first["issues"] if i["code"] == "no_gutter_band")["details"]["boundaries"][0]
        override = band["suggested_crop_override"]
        second = vs.validate_sheet(path, vs.make_spec("character_view", boundary_overrides=[override]))
        self.assertNotIn("no_gutter_band", codes(second))
        self.assertNotIn("touches_cell_edge", codes(second))

    def test_alpha_background_must_be_rgba_and_transparent(self):
        opaque = helpers.view_sheet(self.tmp / "o.png", bg=(255, 0, 255))
        report = vs.validate_sheet(opaque, vs.make_spec("character_view"))
        self.assertIn("background_not_transparent", codes(report, "error"))

    def test_flat_background_is_removed_in_memory_with_recorded_parameters(self):
        path = helpers.view_sheet(self.tmp / "m.png", bg=(255, 0, 255))
        before = sha256_file(path)
        report = vs.validate_sheet(path, vs.make_spec("character_view", background="#ff00ff"))
        self.assertEqual(report["status"], "pass", report["issues"])
        removal = report["sheet"]["background_removal"]
        self.assertTrue(removal["in_memory_only"])
        self.assertEqual(removal["params"]["key"], "#FF00FF")
        self.assertEqual(sha256_file(path), before, "the validator must never write")

    def test_wrong_key_colour_is_reported(self):
        path = helpers.view_sheet(self.tmp / "m.png", bg=(255, 0, 255))
        report = vs.validate_sheet(path, vs.make_spec("character_view", background="#00FF00"))
        self.assertIn("flat_background_mismatch", codes(report, "error"))

    def test_missing_and_non_png_files(self):
        self.assertIn("file_missing", codes(vs.validate_sheet(self.tmp / "none.png", vs.make_spec("icon_source"))))
        fake = self.tmp / "fake.png"
        fake.write_bytes(b"not a png")
        self.assertIn("not_png", codes(vs.validate_sheet(fake, vs.make_spec("icon_source"))))

    def test_vfx_blank_frame_is_only_a_warning(self):
        path = helpers.view_sheet(self.tmp / "v.png", empty_cells=(15,))
        report = vs.validate_sheet(path, vs.make_spec("vfx_source"))
        self.assertEqual(report["status"], "warn")
        self.assertNotIn("idle_height_px", report["measurements"])

    def test_equipment_row_count_gap_and_touching(self):
        good = helpers.equipment_sheet(self.tmp / "e.png", widths=(60, 80, 50))
        report = vs.validate_sheet(good, vs.make_spec("equipment_row", count=3))
        self.assertEqual(report["status"], "pass", report["issues"])
        self.assertEqual(report["measurements"]["object_count"], 3)
        touching = helpers.equipment_sheet(self.tmp / "t.png", widths=(60, 80, 50), touching=True)
        report = vs.validate_sheet(touching, vs.make_spec("equipment_row", count=3))
        issue = next(i for i in report["issues"] if i["code"] == "object_count_mismatch")
        self.assertEqual((issue["details"]["expected"], issue["details"]["found"]), (3, 1))
        self.assertIn("touch", issue["message"])

    def test_equipment_without_count_warns(self):
        good = helpers.equipment_sheet(self.tmp / "e.png")
        self.assertIn("expected_count_unknown", codes(vs.validate_sheet(good, vs.make_spec("equipment_row"))))

    def test_icon_source_size_rules(self):
        small = helpers.save(__import__("numpy").zeros((64, 64, 4), dtype="uint8"), self.tmp / "small.png")
        report = vs.validate_sheet(small, vs.make_spec("icon_source"))
        self.assertIn("icon_too_small", codes(report))
        self.assertIn("icon_empty", codes(report))

    def test_veil_is_a_warning_not_a_failure(self):
        np = __import__("numpy")
        path = helpers.view_sheet(self.tmp / "s.png")
        from art_pipeline.imaging import load_rgba
        pixels, _ = load_rgba(path)
        pixels[:6, :, 3] = 8  # a faint band across the top
        helpers.save(pixels, self.tmp / "veil.png")
        report = vs.validate_sheet(self.tmp / "veil.png", vs.make_spec("character_view"))
        self.assertEqual(report["status"], "warn")
        self.assertIn("alpha_veil", codes(report, "warning"))

    def test_bad_arguments_are_refused(self):
        with self.assertRaises(PipelineError):
            vs.make_spec("not_a_kind")
        with self.assertRaises(PipelineError):
            vs.make_spec("character_view", direction="up")


class ViewSets(helpers.TempCase):
    def make_set(self, east_height, west_height=60, north_height=60):
        paths = {"south": helpers.view_sheet(self.tmp / "south.png", idle_height=60),
                 "east": helpers.view_sheet(self.tmp / "east.png", idle_height=east_height),
                 "west": helpers.view_sheet(self.tmp / "west.png", idle_height=west_height),
                 "north": helpers.view_sheet(self.tmp / "north.png", idle_height=north_height)}
        return {name: str(path) for name, path in paths.items()}

    def test_equal_views_pass(self):
        report = vs.validate_set(self.make_set(60), vs.make_spec("character_view"))
        self.assertEqual(report["status"], "pass")
        self.assertEqual(report["scale"]["worst_deviation_pct"], 0)

    def test_a_30_percent_difference_is_pointed_out_with_the_suggested_scale(self):
        report = vs.validate_set(self.make_set(42), vs.make_spec("character_view"))
        self.assertEqual(report["status"], "warn")
        issue = next(i for i in report["set_issues"] if i["code"] == "scale_mismatch")
        self.assertEqual(issue["details"]["view"], "east")
        self.assertAlmostEqual(issue["details"]["ratio"], 0.7, places=2)
        self.assertAlmostEqual(issue["details"]["deviation_pct"], -30.0, places=0)
        self.assertAlmostEqual(issue["details"]["suggested_scale"], 1.4286, places=3)

    def test_within_tolerance_is_silent_and_strict_scale_fails(self):
        self.assertEqual(vs.validate_set(self.make_set(63), vs.make_spec("character_view"))["status"], "pass")
        strict = vs.validate_set(self.make_set(42), vs.make_spec("character_view"), strict_scale=True)
        self.assertEqual(strict["status"], "fail")

    def test_missing_reference_view_fails(self):
        views = self.make_set(60)
        del views["south"]
        report = vs.validate_set(views, vs.make_spec("character_view"))
        self.assertEqual(report["status"], "fail")
        self.assertIn("reference_missing", [i["code"] for i in report["set_issues"]])


class Cli(helpers.TempCase):
    def test_exit_codes_and_json(self):
        good = helpers.view_sheet(self.tmp / "g.png")
        code, out, _ = self.run_cli("validate_sheet.py", good, "--kind", "character_view")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["status"], "pass")
        bad = helpers.view_sheet(self.tmp / "b.png", empty_cells=(0,))
        code, out, _ = self.run_cli("validate_sheet.py", bad, "--kind", "character_view")
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["status"], "fail")
        code, _, err = self.run_cli("validate_sheet.py", "--kind", "character_view")
        self.assertEqual(code, 2)
        self.assertIn("error:", err)

    def test_set_mode_and_out_file(self):
        sheets = {n: helpers.view_sheet(self.tmp / (n + ".png"), idle_height=h)
                  for n, h in (("south", 60), ("east", 40))}
        out = self.tmp / "report.json"
        code, _, _ = self.run_cli("validate_sheet.py", "--set", "south=%s" % sheets["south"],
                                  "east=%s" % sheets["east"], "--kind", "character_view", "--out", out, "--strict")
        self.assertEqual(code, 1)  # --strict turns the scale warning into a failure
        self.assertEqual(json.loads(out.read_text(encoding="utf-8"))["scope"], "set")


if __name__ == "__main__":
    unittest.main()
