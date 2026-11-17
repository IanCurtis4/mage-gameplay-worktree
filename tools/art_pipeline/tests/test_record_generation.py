import json
import unittest

import helpers
from art_pipeline import provenance as pv
from art_pipeline import record_generation as rg
from art_pipeline.common import PipelineError, sha256_file


class Api(helpers.TempCase):
    def setUp(self):
        super().setUp()
        (self.tmp / "project.godot").write_text("", encoding="utf-8")
        self.folder = self.tmp / "assets/art/e09/characters/sp_ac"
        self.image = helpers.tiny_png(self.folder / "east_v2.png", 5)
        self.ref = helpers.tiny_png(self.tmp / "assets/art/refs/south.png", 9)

    def test_records_hash_size_refs_and_inferred_kind(self):
        result = rg.record_file(self.image, generator="ComfyUI", model="qwen-edit", host="local",
                                request="sp_ac / east", prompt="exact prompt", seed=31, params={"steps": 4},
                                refs=[self.ref], terms="Apache-2.0 model", review_notes="first try")
        self.assertEqual(result["status"], "added")
        loaded = pv.load_provenance(self.folder / "provenance.json")
        record = loaded.records[0]
        self.assertEqual(record["path"], "assets/art/e09/characters/sp_ac/east_v2.png")
        self.assertEqual(record["sha256"], sha256_file(self.image))
        self.assertEqual((record["width"], record["height"]), (8, 8))
        self.assertEqual(record["kind"], "character_view")
        self.assertEqual(record["refs"], [{"path": "assets/art/refs/south.png", "sha256": sha256_file(self.ref)}])
        self.assertEqual(record["generator"]["host"], "local")
        self.assertEqual(record["review"]["status"], "pending")
        self.assertEqual(loaded.check()[0]["status"], "ok")

    def test_recording_twice_is_idempotent_and_a_second_file_is_appended(self):
        kwargs = dict(generator="hand", host="manual", prompt="")
        self.assertEqual(rg.record_file(self.image, **kwargs)["status"], "added")
        self.assertEqual(rg.record_file(self.image, **kwargs)["status"], "unchanged")
        other = helpers.tiny_png(self.folder / "north.png", 6)
        self.assertEqual(rg.record_file(other, **kwargs)["status"], "added")
        self.assertEqual(len(pv.load_provenance(self.folder / "provenance.json").records), 2)

    def test_missing_ref_and_missing_file_are_errors(self):
        with self.assertRaises(PipelineError):
            rg.record_file(self.image, generator="x", prompt="", refs=[self.tmp / "nope.png"])
        with self.assertRaises(PipelineError):
            rg.record_file(self.tmp / "nope.png", generator="x", prompt="")
        result = rg.record_file(self.image, generator="x", prompt="", refs=[self.tmp / "nope.png"],
                                allow_missing_ref=True)
        self.assertEqual(result["record"]["refs"][0]["sha256"], "unavailable")

    def test_files_outside_any_project_use_a_store_relative_path(self):
        outside = self.tmp.parent / ("art_pipeline_outside_%d" % id(self))
        try:
            image = helpers.tiny_png(outside / "out/x.png", 3)
            result = rg.record_file(image, generator="x", prompt="", store=outside / "out/provenance.json")
            self.assertEqual(result["record"]["path"], "x.png")
            document = json.loads((outside / "out/provenance.json").read_text(encoding="utf-8"))
            self.assertEqual(document["path_base"], "store")
        finally:
            import shutil
            shutil.rmtree(outside, ignore_errors=True)

    def test_dry_run_writes_nothing(self):
        result = rg.record_file(self.image, generator="x", prompt="", dry_run=True)
        self.assertEqual(result["status"], "dry_run")
        self.assertFalse((self.folder / "provenance.json").exists())


class Cli(helpers.TempCase):
    def setUp(self):
        super().setUp()
        (self.tmp / "project.godot").write_text("", encoding="utf-8")
        self.folder = self.tmp / "assets/art/e09/creatures/slime"
        self.image = helpers.tiny_png(self.folder / "south.png", 11)
        self.ref = helpers.tiny_png(self.tmp / "ref.png", 12)

    def test_full_command_line(self):
        prompt_file = self.tmp / "prompt.txt"
        prompt_file.write_text("a slime, 4x4 grid\n", encoding="utf-8")
        post = {"tool": "art_pipeline.remove_background", "version": "1.0.0", "params": {"key": "#FF00FF"},
                "input_sha256": "a" * 64, "output_sha256": sha256_file(self.image)}
        code, stdout, err = self.run_cli(
            "record_generation.py", self.image, "--generator", "Gemini Nano Banana", "--model", "Pro", "--host", "cloud",
            "--request", "slime / south", "--prompt-file", prompt_file, "--negative-prompt", "text", "--seed", "4",
            "--param", "steps=4", "--param", "label=\"x\"", "--ref", self.ref, "--post", json.dumps(post),
            "--measure", "idle_height_px=[200,201,199,200]", "--selected", "--review-status", "approved",
            "--review-date", "2026-11-16", "--terms", "free plan, personal use")
        self.assertEqual(code, 0, err)
        self.assertEqual(json.loads(stdout)["status"], "added")
        record = pv.load_provenance(self.folder / "provenance.json").records[0]
        self.assertEqual(record["kind"], "creature_view")
        self.assertEqual(record["prompt"], "a slime, 4x4 grid")
        self.assertEqual(record["params"], {"steps": 4, "label": "x"})
        self.assertEqual(record["post"][0]["tool"], "art_pipeline.remove_background")
        self.assertEqual(record["measurements"]["idle_height_px"], [200, 201, 199, 200])
        self.assertIs(record["selected"], True)
        self.assertEqual(record["terms"], "free plan, personal use")

    def test_prompt_is_required_and_a_v1_store_is_refused(self):
        code, _, err = self.run_cli("record_generation.py", self.image, "--generator", "x")
        self.assertEqual(code, 2)
        self.assertIn("prompt", err)
        v1 = helpers.write_json(self.folder / "provenance.json", [helpers.v1_record("a.png", "0" * 64)])
        before = v1.read_bytes()
        code, _, err = self.run_cli("record_generation.py", self.image, "--generator", "x", "--prompt", "p")
        self.assertEqual(code, 2)
        self.assertIn("provenance_v2.json", err)
        self.assertEqual(v1.read_bytes(), before)
        code, _, _ = self.run_cli("record_generation.py", self.image, "--generator", "x", "--prompt", "p",
                                  "--store", self.folder / "provenance_v2.json")
        self.assertEqual(code, 0)


class ComfyLogs(helpers.TempCase):
    """The logs written by D:/ComfyUI/ragrpg/{qedit,faledit,hfedit}.py."""

    def setUp(self):
        super().setUp()
        (self.tmp / "project.godot").write_text("", encoding="utf-8")
        self.out = self.tmp / "assets/art/e09/characters/mg_dr"
        self.final = helpers.tiny_png(self.out / "job_s31.png", 21)
        self.raw = helpers.tiny_png(self.out / "job_s31_raw.png", 22)
        self.sheet = helpers.tiny_png(self.tmp / "sheet.png", 23)
        self.ref = helpers.tiny_png(self.tmp / "ref.png", 24)

    def job(self, **extra):
        job = {"name": "job", "sheet": str(self.sheet), "refs": [str(self.ref)], "bg": [255, 0, 255], "size": 1024,
               "prompt": "job prompt", "seeds": [31], "mask": {"frac": 0.5}, "out": str(self.out)}
        job.update(extra)
        return job

    def test_qedit_log_fills_generator_model_prompt_seed_refs_and_the_postprocessing_step(self):
        log = {"job": self.job(), "runs": [{"seed": 31, "seconds": 1180, "prompt": "job prompt"}],
               "unet": "qwen-image-edit-2511-Q4_K_M.gguf", "clip": "clip.safetensors", "vae": "vae.safetensors",
               "lora": "lightning-4steps.safetensors"}
        log_path = helpers.write_json(self.out / "job_log.json", log)
        code, stdout, err = self.run_cli("record_generation.py", self.final, "--from-comfy-log", log_path,
                                         "--store", self.out / "provenance.json")
        self.assertEqual(code, 0, err)
        record = pv.load_provenance(self.out / "provenance.json").records[0]
        self.assertEqual(record["generator"]["name"], "ComfyUI")
        self.assertEqual(record["generator"]["model"], "qwen-image-edit-2511-Q4_K_M.gguf")
        self.assertEqual(record["generator"]["host"], "local")
        self.assertEqual((record["seed"], record["prompt"], record["request"]), (31, "job prompt", "job"))
        self.assertEqual(record["params"]["lora"], "lightning-4steps.safetensors")
        self.assertEqual(record["params"]["seconds"], 1180)
        self.assertEqual([r["sha256"] for r in record["refs"]], [sha256_file(self.sheet), sha256_file(self.ref)])
        self.assertEqual(record["post"][0]["input_sha256"], sha256_file(self.raw))
        self.assertEqual(record["post"][0]["output_sha256"], sha256_file(self.final))

    def test_tile_jobs_whose_refs_are_objects_with_cells(self):
        log = helpers.write_json(self.tmp / "tiles_log.json", {
            "job": self.job(mode="head_tiles", refs=[{"path": str(self.ref), "cells": [[0, 0], [0, 1]]}]),
            "runs": [{"seed": 31, "seconds": 5, "prompt": "tiles prompt"}], "unet": "u", "clip": "c", "vae": "v",
            "lora": "l"})
        fields = rg.comfy_log_fields(log, self.final)
        self.assertEqual(fields["ref_paths"], [str(self.sheet), str(self.ref)])
        self.assertEqual(fields["params"]["mode"], "head_tiles")

    def test_fal_and_hugging_face_logs_are_cloud(self):
        fal = helpers.write_json(self.tmp / "fal_log.json", {
            "job": self.job(), "runs": [{"seed": 31, "seconds": 40, "prompt": "p", "size": 1024, "steps": 28,
                                         "guidance": 4.5, "est_usd": 0.0315}],
            "backend": "fal.ai fal-ai/qwen-image-edit-2511"})
        fields = rg.comfy_log_fields(fal, self.final)
        self.assertEqual((fields["generator"], fields["host"], fields["model"]),
                         ("fal.ai", "cloud", "fal-ai/qwen-image-edit-2511"))
        self.assertEqual(fields["params"]["est_usd"], 0.0315)
        hf = helpers.write_json(self.tmp / "hf_log.json", {
            "job": self.job(), "runs": [{"seed": 31, "seconds": 20, "prompt": "p", "steps": 4}],
            "backend": "LPX55/Qwen-Image-Edit-2511-Turbo-Lightning"})
        fields = rg.comfy_log_fields(hf, self.final)
        self.assertEqual((fields["generator"], fields["host"]), ("Hugging Face Space", "cloud"))


if __name__ == "__main__":
    unittest.main()
