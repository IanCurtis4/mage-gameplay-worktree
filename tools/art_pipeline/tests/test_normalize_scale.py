import json
import unittest

import helpers
from art_pipeline import normalize_scale as ns
from art_pipeline import validate_sheet as vs
from art_pipeline.common import PipelineError, sha256_file
from art_pipeline.imaging import load_rgba


class Normalize(helpers.TempCase):
    def test_a_short_view_is_scaled_up_to_the_reference_height(self):
        east = helpers.view_sheet(self.tmp / "east.png", idle_height=42)  # 0.7 of 60
        out = self.tmp / "east_norm.png"
        report = ns.normalize_view(east, out, 60.0)
        self.assertTrue(report["changed"])
        self.assertAlmostEqual(report["scale"], 60 / 42, places=4)
        self.assertLessEqual(abs(report["after_idle_height_px"] - 60), 2)
        self.assertEqual(report["output_size"], [round(400 * 60 / 42)] * 2)
        validation = vs.validate_sheet(out, vs.make_spec("character_view", "east"))
        self.assertEqual(validation["status"], "pass", validation["issues"])

    def test_nearest_filter_invents_no_new_colours(self):
        east = helpers.view_sheet(self.tmp / "east.png", idle_height=42)
        out = self.tmp / "east_norm.png"
        ns.normalize_view(east, out, 60.0)
        before = {tuple(p) for p in load_rgba(east)[0].reshape(-1, 4)}
        after = {tuple(p) for p in load_rgba(out)[0].reshape(-1, 4)}
        self.assertLessEqual(after, before, "no smoothing: every output pixel already existed in the input")
        self.assertEqual(report_filter(ns.normalize_view(east, self.tmp / "b.png", 60.0)), "nearest")

    def test_lanczos_is_an_explicit_recorded_opt_in(self):
        east = helpers.view_sheet(self.tmp / "east.png", idle_height=42)
        report = ns.normalize_view(east, self.tmp / "l.png", 60.0, filter_name="lanczos")
        self.assertTrue(report["post"]["params"]["smoothing"])
        after = {tuple(p) for p in load_rgba(self.tmp / "l.png")[0].reshape(-1, 4)}
        before = {tuple(p) for p in load_rgba(east)[0].reshape(-1, 4)}
        self.assertFalse(after <= before)

    def test_the_post_step_matches_the_provenance_shape_and_hashes(self):
        east = helpers.view_sheet(self.tmp / "east.png", idle_height=80)
        out = self.tmp / "o.png"
        post = ns.normalize_view(east, out, 60.0)["post"]
        self.assertEqual(set(post), {"tool", "version", "params", "input_sha256", "output_sha256"})
        self.assertEqual(post["input_sha256"], sha256_file(east))
        self.assertEqual(post["output_sha256"], sha256_file(out))
        self.assertEqual(post["params"]["filter"], "nearest")

    def test_within_min_change_writes_nothing(self):
        east = helpers.view_sheet(self.tmp / "east.png", idle_height=60)
        out = self.tmp / "o.png"
        report = ns.normalize_view(east, out, 61.0)
        self.assertFalse(report["changed"])
        self.assertFalse(out.exists())

    def test_never_overwrites_the_source_or_an_existing_output(self):
        east = helpers.view_sheet(self.tmp / "east.png", idle_height=42)
        with self.assertRaises(PipelineError):
            ns.normalize_view(east, east, 60.0)
        out = self.tmp / "o.png"
        ns.normalize_view(east, out, 60.0)
        with self.assertRaises(PipelineError):
            ns.normalize_view(east, out, 60.0)
        ns.normalize_view(east, out, 60.0, force=True)

    def test_empty_idle_row_is_a_clear_error(self):
        sheet = helpers.view_sheet(self.tmp / "e.png", empty_cells=(0, 1, 2, 3))
        with self.assertRaises(PipelineError):
            ns.measure_idle_height(sheet)


def report_filter(report):
    return report["filter"]


class Cli(helpers.TempCase):
    def test_set_mode_normalises_only_the_views_that_differ(self):
        views = {"south": helpers.view_sheet(self.tmp / "south.png", idle_height=60),
                 "east": helpers.view_sheet(self.tmp / "east.png", idle_height=42),
                 "west": helpers.view_sheet(self.tmp / "west.png", idle_height=60)}
        out_dir = self.tmp / "norm"
        code, stdout, _ = self.run_cli("normalize_scale.py", "--set", *("%s=%s" % kv for kv in views.items()),
                                       "--out-dir", out_dir)
        self.assertEqual(code, 0)
        result = json.loads(stdout)
        self.assertTrue(result["views"]["east"]["changed"])
        self.assertFalse(result["views"]["west"]["changed"])
        self.assertEqual(sorted(p.name for p in out_dir.iterdir()), ["east.png"])

    def test_single_mode_with_reference(self):
        south = helpers.view_sheet(self.tmp / "south.png", idle_height=60)
        east = helpers.view_sheet(self.tmp / "east.png", idle_height=42)
        code, stdout, _ = self.run_cli("normalize_scale.py", "--reference", south, east, self.tmp / "o.png")
        self.assertEqual(code, 0)
        self.assertTrue(json.loads(stdout)["changed"])
        code, _, err = self.run_cli("normalize_scale.py", east, self.tmp / "p.png")
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
