import json
import unittest

import helpers
from art_pipeline import remove_background as rb
from art_pipeline.common import sha256_file
from art_pipeline.imaging import load_rgba, np

MAGENTA = (255, 0, 255)


def flat_image(size=40, key=MAGENTA):
    pixels = np.zeros((size, size, 4), dtype=np.uint8)
    pixels[:, :] = key + (255,)
    return pixels


class Algorithm(helpers.TempCase):
    def test_background_becomes_transparent_and_figure_is_untouched(self):
        pixels = flat_image()
        pixels[10:30, 10:30] = (30, 160, 60, 255)
        out, params, stats = rb.remove_flat_background(pixels, MAGENTA)
        self.assertEqual(tuple(out[0, 0]), (0, 0, 0, 0))
        self.assertEqual(tuple(out[20, 20]), (30, 160, 60, 255))
        self.assertEqual(int((out[:, :, 3] == 255).sum()), 400)
        self.assertEqual(stats["background_pixels"], 40 * 40 - 400)
        self.assertEqual(params["key"], "#FF00FF")
        self.assertEqual(params["mode"], "global")
        self.assertIsNot(out, pixels)
        self.assertEqual(tuple(pixels[0, 0]), MAGENTA + (255,), "the input array must not be modified")

    def test_generator_noise_inside_tolerance_is_removed(self):
        pixels = flat_image()
        pixels[5:8, 5:8] = (250, 6, 249, 255)  # slightly off the key
        pixels[10:30, 10:30] = (30, 160, 60, 255)
        out, _, _ = rb.remove_flat_background(pixels, MAGENTA, tolerance=48)
        self.assertEqual(out[6, 6, 3], 0)

    def test_antialiased_fringe_is_cleaned_and_snapped_to_the_figure_colour(self):
        pixels = flat_image()
        pixels[10:30, 10:30] = (30, 160, 60, 255)
        pixels[10:30, 9] = (165, 64, 177, 255)   # 40% figure + 60% key, leftmost ring
        pixels[10:30, 30] = (60, 140, 90, 255)   # mostly figure, rightmost ring
        out, params, stats = rb.remove_flat_background(pixels, MAGENTA, edge_steps=1)
        self.assertEqual(out[20, 9, 3], 0, "a pixel under 50% figure is background")
        self.assertEqual(tuple(out[20, 30]), (30, 160, 60, 255), "a mostly-figure pixel is snapped, no key halo")
        self.assertGreater(stats["edge_pixels_processed"], 0)
        no_edge, _, _ = rb.remove_flat_background(pixels, MAGENTA, edge_steps=0)
        self.assertEqual(tuple(no_edge[20, 30, :3]), (60, 140, 90), "edge_steps=0 leaves the ring alone")

    def test_connected_mode_keeps_enclosed_key_like_pixels_but_global_removes_them(self):
        pixels = flat_image()
        pixels[10:30, 10:30] = (30, 160, 60, 255)
        pixels[18:22, 18:22] = (250, 0, 250, 255)  # a hole painted in key colour inside the figure
        glob, _, _ = rb.remove_flat_background(pixels, MAGENTA, mode="global", edge_steps=0)
        conn, _, stats = rb.remove_flat_background(pixels, MAGENTA, mode="connected", edge_steps=0)
        self.assertEqual(glob[20, 20, 3], 0)
        self.assertEqual(conn[20, 20, 3], 255)
        self.assertEqual(stats["remaining_key_like_pixels"], 16)

    def test_veil_alpha_is_cleared_on_request(self):
        pixels = np.zeros((20, 20, 4), dtype=np.uint8)
        pixels[:, :, :3] = MAGENTA
        pixels[:, :, 3] = 8
        pixels[5:15, 5:15] = (10, 10, 10, 255)
        out, params, _ = rb.remove_flat_background(pixels, (0, 0, 0), tolerance=0, veil_alpha=16, edge_steps=0)
        self.assertEqual(int(out[0, 0, 3]), 0)
        self.assertEqual(params["veil_alpha"], 16)

    def test_bad_parameters_are_refused(self):
        from art_pipeline.common import PipelineError
        with self.assertRaises(PipelineError):
            rb.remove_flat_background(flat_image(), MAGENTA, mode="nope")
        with self.assertRaises(PipelineError):
            rb.remove_flat_background(flat_image(), MAGENTA, tolerance=-1)

    def test_corner_match(self):
        pixels = flat_image()
        self.assertTrue(rb.corner_match(pixels, MAGENTA, 48)[0])
        self.assertFalse(rb.corner_match(pixels, (0, 255, 0), 48)[0])


class Cli(helpers.TempCase):
    def test_writes_rgba_png_and_reports_the_post_step(self):
        source = helpers.view_sheet(self.tmp / "in.png", bg=MAGENTA)
        before = sha256_file(source)
        out = self.tmp / "out.png"
        step_file = self.tmp / "step.json"
        code, stdout, _ = self.run_cli("remove_background.py", source, out, "--key", "#FF00FF",
                                       "--emit-post", step_file)
        self.assertEqual(code, 0)
        report = json.loads(stdout)
        post = report["post"]
        self.assertEqual(post["tool"], "art_pipeline.remove_background")
        self.assertEqual(post["input_sha256"], before)
        self.assertEqual(post["output_sha256"], sha256_file(out))
        self.assertEqual(json.loads(step_file.read_text(encoding="utf-8"))["params"]["key"], "#FF00FF")
        pixels, info = load_rgba(out)
        self.assertEqual(info["mode"], "RGBA")
        self.assertEqual(int(pixels[0, 0, 3]), 0)
        self.assertEqual(sha256_file(source), before, "the source is never modified")

    def test_refuses_to_overwrite_or_write_in_place(self):
        source = helpers.view_sheet(self.tmp / "in.png", bg=MAGENTA)
        code, _, err = self.run_cli("remove_background.py", source, source, "--key", "#FF00FF")
        self.assertEqual(code, 1)
        out = self.tmp / "out.png"
        self.assertEqual(self.run_cli("remove_background.py", source, out, "--key", "#FF00FF")[0], 0)
        code, _, err = self.run_cli("remove_background.py", source, out, "--key", "#FF00FF")
        self.assertEqual(code, 1)
        self.assertIn("--force", err)

    def test_wrong_key_exits_2_but_still_reports(self):
        source = helpers.view_sheet(self.tmp / "in.png", bg=MAGENTA)
        code, stdout, _ = self.run_cli("remove_background.py", source, self.tmp / "o.png", "--key", "#00FF00")
        self.assertEqual(code, 2)
        self.assertFalse(json.loads(stdout)["corners_match_key"])


if __name__ == "__main__":
    unittest.main()
