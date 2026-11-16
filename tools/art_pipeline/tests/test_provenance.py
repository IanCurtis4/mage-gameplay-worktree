import json
import unittest

import _bootstrap
import helpers
from art_pipeline import provenance as pv
from art_pipeline.common import PipelineError, sha256_file


_SEED = [0]


def make_png(folder, name):
    _SEED[0] += 1
    path = helpers.tiny_png(folder / name, _SEED[0])
    return path, sha256_file(path)


class ReadV1(helpers.TempCase):
    def test_v1_variants_are_accepted_without_rewriting_the_original(self):
        folder = self.tmp / "assets/art/e08_codex_1116/characters/druid"
        a, a_sha = make_png(folder, "south.png")
        b, b_sha = make_png(folder, "east.png")
        (self.tmp / "project.godot").write_text("", encoding="utf-8")
        records = [
            helpers.v1_record("assets/art/e08_codex_1116/characters/druid/south.png", a_sha,
                              references=[{"path": "x/ref.png", "sha256": "0" * 64}], width=8, height=8),
            helpers.v1_record("assets/art/e08_codex_1116/characters/druid/east.png", b_sha, width=8, height=8),
        ]
        prov = helpers.write_json(folder / "provenance.json", records)
        before = prov.read_bytes()
        loaded = pv.load_provenance(prov)
        self.assertEqual(loaded.version, 1)
        self.assertEqual(len(loaded.records), 2)
        self.assertIsNone(loaded.records[0]["selected"], "1116-style records carry no selected flag")
        self.assertFalse(loaded.has_selection_info())
        self.assertEqual(loaded.records[0]["kind"], "character_view")
        self.assertEqual(loaded.records[0]["refs"], [{"path": "x/ref.png", "sha256": "0" * 64}])
        self.assertEqual(loaded.records[1]["refs"], [])
        self.assertEqual(loaded.records[0]["generator"]["name"], "Codex built-in imagegen")
        self.assertEqual(loaded.records[0]["review"]["status"], "legacy")
        self.assertEqual(prov.read_bytes(), before, "reading never modifies a v1 file")
        for record in loaded.records:
            self.assertEqual(pv.validate_record(record), [])

    def test_extras_idle_height_and_crop_overrides_survive(self):
        folder = self.tmp / "assets/art/e08_codex_1121/characters/br_ac"
        a, a_sha = make_png(folder, "east.png")
        (self.tmp / "project.godot").write_text("", encoding="utf-8")
        record = helpers.v1_record("assets/art/e08_codex_1121/characters/br_ac/east.png", a_sha, width=8, height=8,
                                   selected=True, idle_height_px=[289, 288, 282, 290],
                                   crop_overrides=[{"row": 4, "boundary_after_column": 3, "x_px": 813,
                                                    "alpha_threshold": 16}])
        loaded = pv.load_provenance(helpers.write_json(folder / "provenance.json", [record]))
        converted = loaded.records[0]
        self.assertTrue(converted["selected"])
        self.assertEqual(converted["measurements"]["idle_height_px"], [289, 288, 282, 290])
        self.assertEqual(converted["legacy"]["crop_overrides"][0]["x_px"], 813)

    def test_paths_relative_to_the_batch_folder_resolve_and_check(self):
        batch = self.tmp / "assets/art/e08_codex_1114"
        folder = batch / "equipment_icons"
        a, a_sha = make_png(folder, "jewelry.png")
        record = helpers.v1_record("equipment_icons/jewelry.png", a_sha, width=8, height=8)
        loaded = pv.load_provenance(helpers.write_json(folder / "provenance.json", [record]))
        result = loaded.check()[0]
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["resolved_via"], "batch_folder")

    def test_check_reports_missing_and_changed_files(self):
        folder = self.tmp / "p/assets/art/b/x"
        a, a_sha = make_png(folder, "a.png")
        (self.tmp / "p/project.godot").write_text("", encoding="utf-8")
        records = [helpers.v1_record("assets/art/b/x/a.png", a_sha, width=8, height=8),
                   helpers.v1_record("assets/art/b/x/gone.png", "1" * 64),
                   helpers.v1_record("assets/art/b/x/a.png", "2" * 64, width=8, height=8)]
        loaded = pv.load_provenance(helpers.write_json(folder / "provenance.json", records))
        self.assertEqual([r["status"] for r in loaded.check()], ["ok", "missing", "sha_mismatch"])

    def test_unknown_formats_are_refused(self):
        bad = helpers.write_json(self.tmp / "bad.json", {"hello": 1})
        with self.assertRaises(PipelineError):
            pv.load_provenance(bad)


class RealE08Records(unittest.TestCase):
    """The versioned 1116-1118 records of this repository: v1, with the 1116 gap."""

    ART = _bootstrap.REPO / "assets/art"

    def provenance_files(self, batch):
        return sorted((self.ART / batch).rglob("provenance.json"))

    def test_round_1116_has_no_selected_flag_and_still_loads_and_verifies(self):
        files = self.provenance_files("e08_codex_1116")
        if not files:
            self.skipTest("assets/art/e08_codex_1116 not present in this checkout")
        total = 0
        for path in files:
            loaded = pv.load_provenance(path)
            self.assertFalse(loaded.has_selection_info(), path)
            self.assertTrue(all(r["selected"] is None for r in loaded.records))
            for result in loaded.check():
                self.assertEqual(result["status"], "ok", (path, result))
                total += 1
        self.assertGreater(total, 20)

    def test_rounds_1117_and_1118_load_and_every_recorded_hash_matches(self):
        count = 0
        for batch in ("e08_codex_1117", "e08_codex_1118"):
            for path in self.provenance_files(batch):
                loaded = pv.load_provenance(path)
                self.assertTrue(loaded.has_selection_info(), path)
                for result in loaded.check():
                    self.assertEqual(result["status"], "ok", (path, result))
                    count += 1
        if not count:
            self.skipTest("no 1117/1118 provenance in this checkout")
        self.assertGreater(count, 60)


class WriteV2(helpers.TempCase):
    def record(self, folder, name="a.png", **extra):
        path, sha = make_png(folder, name)
        return pv.new_record("assets/art/x/" + name, sha, 8, 8, "character_view", "ComfyUI", "req", "the prompt",
                             model="qwen", host="local", seed=7, params={"steps": 4}, **extra)

    def test_new_record_is_complete_and_valid(self):
        record = self.record(self.tmp)
        self.assertEqual(pv.validate_record(record), [])
        for key in pv.REQUIRED:
            self.assertIn(key, record)
        self.assertEqual(record["generator"], {"name": "ComfyUI", "model": "qwen", "host": "local", "version": None})
        self.assertEqual(record["review"]["status"], "pending")

    def test_invalid_records_are_refused(self):
        with self.assertRaises(PipelineError):
            pv.new_record("a.png", "short", 1, 1, "character_view", "x", host="local")
        with self.assertRaises(PipelineError):
            pv.new_record("a.png", "0" * 64, 1, 1, "bogus", "x")
        with self.assertRaises(PipelineError):
            pv.new_record("a.png", "0" * 64, 1, 1, "other", "x", host="mars")

    def test_append_round_trip_idempotence_and_conflict(self):
        store = self.tmp / "provenance.json"
        record = self.record(self.tmp)
        self.assertEqual(pv.append_record(store, record), "added")
        self.assertEqual(pv.append_record(store, record), "unchanged")
        changed = dict(record, request="other")
        with self.assertRaises(PipelineError):
            pv.append_record(store, changed)
        self.assertEqual(pv.append_record(store, changed, replace=True), "replaced")
        loaded = pv.load_provenance(store)
        self.assertEqual(loaded.version, 2)
        self.assertEqual(loaded.records[0]["request"], "other")
        self.assertEqual(json.loads(store.read_text(encoding="utf-8"))["schema"], pv.SCHEMA_V2)

    def test_a_v1_file_is_never_appended_to(self):
        store = helpers.write_json(self.tmp / "provenance.json", [helpers.v1_record("a.png", "0" * 64)])
        before = store.read_bytes()
        with self.assertRaises(PipelineError) as raised:
            pv.append_record(store, self.record(self.tmp))
        self.assertIn("provenance_v2.json", str(raised.exception))
        self.assertEqual(store.read_bytes(), before)

    def test_upgrade_cli_writes_a_new_file_and_refuses_to_overwrite(self):
        folder = self.tmp / "assets/art/e08_codex_1116/characters/druid"
        _, sha = make_png(folder, "south.png")
        (self.tmp / "project.godot").write_text("", encoding="utf-8")
        old = helpers.write_json(folder / "provenance.json",
                                 [helpers.v1_record("assets/art/e08_codex_1116/characters/druid/south.png", sha,
                                                    width=8, height=8)])
        before = old.read_bytes()
        new = self.tmp / "v2.json"
        code, _, _ = self.run_cli("provenance.py", "upgrade", old, new)
        self.assertEqual(code, 0)
        self.assertEqual(pv.load_provenance(new).version, 2)
        self.assertEqual(old.read_bytes(), before)
        self.assertEqual(self.run_cli("provenance.py", "upgrade", old, new)[0], 2)
        self.assertEqual(self.run_cli("provenance.py", "check", old)[0], 0)


if __name__ == "__main__":
    unittest.main()
