import json
import os
import unittest

import helpers
from art_pipeline import archive as ar
from art_pipeline.common import PipelineError, sha256_file


class Fixture(helpers.TempCase):
    def setUp(self):
        super().setUp()
        self.source = self.tmp / "staging/assets/art"
        self.archive = self.tmp / "archive/e08"
        self.index = self.tmp / "docs/index.json"
        self.folder = self.source / "e08_codex_1123/characters/sp_ac"
        self.files = {}
        records = []
        for seed, name in enumerate(("south.png", "east.png", "east_v2.png"), start=1):
            path = helpers.tiny_png(self.folder / name, seed)
            self.files[name] = path
            records.append(helpers.v1_record("assets/art/e08_codex_1123/characters/sp_ac/" + name,
                                             sha256_file(path), width=8, height=8, selected=name != "east.png"))
        helpers.write_json(self.folder / "provenance.json", records)
        (self.folder / "stale.png.import").write_text("import cache", encoding="utf-8")

    def copy(self, **kwargs):
        return ar.archive_batches(self.source, self.archive, ["e08_codex_1123"], self.index, **kwargs)

    def snapshot(self):
        return {str(p): (sha256_file(p), helpers.file_state(p)) for p in self.source.rglob("*") if p.is_file()}


class Copy(Fixture):
    def test_copies_verifies_and_writes_the_index(self):
        report = self.copy()
        self.assertTrue(report["ok"], report)
        self.assertEqual(report["copied"], 4)  # 3 png + provenance.json; the .import is skipped
        index = json.loads(self.index.read_text(encoding="utf-8"))
        self.assertEqual(index["schema"], ar.INDEX_SCHEMA)
        self.assertEqual(index["totals"]["png"], 3)
        by_path = {e["path"]: e for e in index["entries"]}
        entry = by_path["e08_codex_1123/characters/sp_ac/east_v2.png"]
        self.assertEqual(entry["sha256"], sha256_file(self.files["east_v2.png"]))
        self.assertEqual(entry["size"], self.files["east_v2.png"].stat().st_size)
        self.assertTrue(entry["selected"])
        self.assertFalse(by_path["e08_codex_1123/characters/sp_ac/east.png"]["selected"])
        self.assertEqual(entry["archived_path"], entry["path"])
        self.assertNotIn("e08_codex_1123/characters/sp_ac/stale.png.import", by_path)
        for e in index["entries"]:
            self.assertEqual(sha256_file(self.archive / e["archived_path"]), e["sha256"])

    def test_the_source_is_never_touched(self):
        before = self.snapshot()
        self.copy()
        self.copy()
        self.assertEqual(self.snapshot(), before, "no source file was changed, moved or deleted")

    def test_second_run_is_idempotent(self):
        self.copy()
        report = self.copy()
        self.assertEqual((report["copied"], report["already_archived"]), (0, 4))
        self.assertTrue(report["ok"])

    def test_dry_run_writes_nothing(self):
        report = self.copy(dry_run=True)
        self.assertEqual(report["copied"], 4)
        self.assertFalse(self.archive.exists())
        self.assertFalse(self.index.exists())

    def test_never_overwrites_different_bytes_in_the_archive(self):
        self.copy()
        target = self.archive / "e08_codex_1123/characters/sp_ac/south.png"
        target.write_bytes(b"older, different bytes")
        report = self.copy()
        self.assertFalse(report["ok"])
        self.assertEqual(report["refused_overwrite"][0]["path"], "e08_codex_1123/characters/sp_ac/south.png")
        self.assertEqual(target.read_bytes(), b"older, different bytes", "the archived file must be left as it was")

    def test_a_failed_copy_leaves_no_partial_file(self):
        original = ar._copy_exclusive

        def bad_copy(source, destination, expected_sha):
            return original(source, destination, "0" * 64)  # force the hash check to fail

        ar._copy_exclusive = bad_copy
        try:
            report = self.copy()
        finally:
            ar._copy_exclusive = original
        self.assertEqual(len(report["errors"]), 4)
        self.assertFalse(any(self.archive.rglob("*.png")) if self.archive.exists() else False)

    def test_the_index_never_changes_the_hash_of_a_known_path(self):
        self.copy()
        self.files["south.png"].write_bytes(self.files["south.png"].read_bytes() + b"\0")  # source changes later
        os.remove(self.archive / "e08_codex_1123/characters/sp_ac/south.png")
        report = self.copy()
        self.assertEqual(report["index_conflicts"][0]["path"], "e08_codex_1123/characters/sp_ac/south.png")
        index = json.loads(self.index.read_text(encoding="utf-8"))
        old = {e["path"]: e for e in index["entries"]}["e08_codex_1123/characters/sp_ac/south.png"]
        self.assertNotEqual(old["sha256"], sha256_file(self.files["south.png"]))

    def test_the_archive_must_be_outside_the_source(self):
        with self.assertRaises(PipelineError):
            ar.archive_batches(self.source, self.source / "inside", ["e08_codex_1123"])

    def test_unknown_batch_is_an_error(self):
        with self.assertRaises(PipelineError):
            ar.archive_batches(self.source, self.archive, ["e08_codex_9999"])


class Verify(Fixture):
    def test_verify_detects_a_tampered_or_missing_archive_file(self):
        self.copy()
        self.assertTrue(ar.verify_archive(self.archive, self.index, self.source)["ok"])
        (self.archive / "e08_codex_1123/characters/sp_ac/east.png").write_bytes(b"x")
        (self.archive / "e08_codex_1123/characters/sp_ac/south.png").unlink()
        problems = {p["path"].split("/")[-1]: p["problem"] for p in ar.verify_archive(self.archive, self.index)["problems"]}
        self.assertEqual(problems, {"east.png": "archive_sha256_mismatch", "south.png": "missing_in_archive"})

    def test_cli_copy_and_verify(self):
        code, stdout, _ = self.run_cli("archive.py", "copy", "--source", self.source, "--archive", self.archive,
                                       "--batch", "e08_codex_1123", "--index", self.index)
        self.assertEqual(code, 0, stdout)
        code, stdout, _ = self.run_cli("archive.py", "verify", "--archive", self.archive, "--index", self.index)
        self.assertEqual(code, 0)
        self.assertTrue(json.loads(stdout)["ok"])
        (self.archive / "e08_codex_1123/characters/sp_ac/east.png").write_bytes(b"x")
        self.assertEqual(self.run_cli("archive.py", "verify", "--archive", self.archive, "--index", self.index)[0], 1)


if __name__ == "__main__":
    unittest.main()
