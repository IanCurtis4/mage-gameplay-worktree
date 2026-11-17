import json
import unittest

import helpers
from art_pipeline import provenance as pv
from art_pipeline import selection as sel
from art_pipeline.common import PipelineError, sha256_file


class Fixture(helpers.TempCase):
    """assets/art/e08_codex_1123/characters/sp_ac with south, east, east_v2, north, north_v2."""

    def build(self, selected, with_flag=True):
        self.folder = self.tmp / "assets/art/e08_codex_1123/characters/sp_ac"
        (self.tmp / "project.godot").write_text("", encoding="utf-8")
        records = []
        self.shas = {}
        for index, name in enumerate(("south.png", "east.png", "east_v2.png", "north.png", "north_v2.png")):
            path = helpers.tiny_png(self.folder / name, index + 1)
            self.shas[name] = sha256_file(path)
            extra = {"selected": name in selected} if with_flag else {}
            records.append(helpers.v1_record("assets/art/e08_codex_1123/characters/sp_ac/" + name,
                                             self.shas[name], width=8, height=8, **extra))
        self.prov = helpers.write_json(self.folder / "provenance.json", records)
        return pv.load_provenance(self.prov)


class Derive(Fixture):
    def test_slots_strip_the_version_suffix_and_pick_the_selected_file(self):
        provenance = self.build({"south.png", "east_v2.png", "north_v2.png"})
        items, report = sel.derive_from_provenance(provenance, self.folder)
        self.assertEqual(sorted(items), ["east", "north", "south"])
        self.assertEqual(items["east"], {"path": "east_v2.png", "sha256": self.shas["east_v2.png"]})
        self.assertEqual(report["conflicts"], [])
        self.assertTrue(report["has_selection_info"])

    def test_two_selected_files_for_one_slot_is_a_conflict(self):
        provenance = self.build({"south.png", "east.png", "east_v2.png"})
        items, report = sel.derive_from_provenance(provenance, self.folder)
        self.assertEqual(report["conflicts"][0]["slot"], "east")
        self.assertNotIn("east", items)

    def test_a_slot_with_versions_but_no_selected_is_reported(self):
        provenance = self.build({"south.png", "east.png"})
        items, report = sel.derive_from_provenance(provenance, self.folder)
        self.assertEqual(report["unselected_slots"][0]["slot"], "north")
        self.assertEqual(report["unselected_slots"][0]["versions"], ["north.png", "north_v2.png"])

    def test_round_1116_style_provenance_needs_the_explicit_latest_heuristic(self):
        provenance = self.build(set(), with_flag=False)
        items, report = sel.derive_from_provenance(provenance, self.folder)
        self.assertEqual(items, {})
        self.assertFalse(report["has_selection_info"])
        items, report = sel.derive_from_provenance(provenance, self.folder, latest_if_unrecorded=True)
        self.assertEqual(items["east"]["path"], "east_v2.png")
        self.assertEqual(sorted(report["inferred"]), ["east", "north", "south"])
        self.assertIn("inferred", items["east"])


class ReadAndWrite(Fixture):
    def make_selection(self):
        provenance = self.build({"south.png", "east_v2.png", "north_v2.png"})
        items, _ = sel.derive_from_provenance(provenance, self.folder)
        path = self.folder / "selection.json"
        self.assertEqual(sel.save_selection(path, "e08_codex_1123/characters/sp_ac", items), "written")
        return path

    def test_round_trip_and_resolution_verifies_the_hash(self):
        path = self.make_selection()
        selection = sel.load_selection(path)
        self.assertEqual(selection.slots(), ["east", "north", "south"])
        self.assertEqual(selection.resolve("east"), (self.folder / "east_v2.png").resolve())
        self.assertEqual(sorted(selection.resolve_all()), ["east", "north", "south"])
        self.assertEqual(json.loads(path.read_text(encoding="utf-8"))["schema"], sel.SCHEMA)

    def test_a_changed_file_is_refused_by_the_reader(self):
        selection = sel.load_selection(self.make_selection())
        (self.folder / "east_v2.png").write_bytes(b"tampered")
        with self.assertRaises(PipelineError) as raised:
            selection.resolve("east")
        self.assertIn("changed", str(raised.exception))
        self.assertTrue(selection.resolve("east", verify=False).is_file())

    def test_missing_slot_and_missing_file_are_clear_errors(self):
        selection = sel.load_selection(self.make_selection())
        with self.assertRaises(PipelineError):
            selection.get("up")
        (self.folder / "south.png").unlink()
        with self.assertRaises(PipelineError):
            selection.resolve("south")

    def test_save_refuses_to_replace_a_different_selection_silently(self):
        path = self.make_selection()
        items = sel.load_selection(path).items
        self.assertEqual(sel.save_selection(path, "x", items), "unchanged")
        other = dict(items, east={"path": "east.png", "sha256": self.shas["east.png"]})
        with self.assertRaises(PipelineError):
            sel.save_selection(path, "x", other)
        self.assertEqual(sel.save_selection(path, "x", other, replace=True), "written")

    def test_cli_derive_show_check(self):
        self.build({"south.png", "east_v2.png", "north_v2.png"})
        out = self.folder / "selection.json"
        code, stdout, _ = self.run_cli("selection.py", "derive", self.prov, "--out", out)
        self.assertEqual(code, 0, stdout)
        self.assertEqual(self.run_cli("selection.py", "show", out)[0], 0)
        self.assertEqual(self.run_cli("selection.py", "check", out)[0], 0)
        (self.folder / "north_v2.png").write_bytes(b"x")
        code, stdout, _ = self.run_cli("selection.py", "check", out)
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(stdout)["problems"][0]["slot"], "north")

    def test_slot_name_helpers(self):
        self.assertEqual(sel.slot_name("south_v2.png"), "south")
        self.assertEqual(sel.slot_name("weapons_h1_v2.png"), "weapons_h1")
        self.assertEqual(sel.slot_name("east.png"), "east")
        self.assertEqual(sel.version_number("north_v3.png"), 3)
        self.assertEqual(sel.version_number("north.png"), 1)


if __name__ == "__main__":
    unittest.main()
