import json
import unittest

import helpers
from art_pipeline import validate_batch as vb
from art_pipeline.common import sha256_file

VIEW_HEIGHTS = {"south": 60, "east": 42, "west": 60, "north": 60}


class Batch(helpers.TempCase):
    def setUp(self):
        super().setUp()
        (self.tmp / "project.godot").write_text("", encoding="utf-8")
        self.art = self.tmp / "assets/art"

    def figure(self, batch, figure_id, files, selected=None, flag=True, overflow=None, overrides=None,
               folder="characters"):
        """files: {file name: idle height}. selected: names flagged true (None = all)."""
        directory = self.art / batch / folder / figure_id
        records = []
        for name, height in files.items():
            path = helpers.view_sheet(directory / name, idle_height=height,
                                      overflow=(overflow or {}).get(name))
            extra = {"selected": (selected is None or name in selected)} if flag else {}
            record = helpers.v1_record("assets/art/%s/%s/%s/%s" % (batch, folder, figure_id, name),
                                       sha256_file(path), width=400, height=400, **extra)
            if overrides and name in overrides:
                record["crop_overrides"] = overrides[name]
            records.append(record)
        helpers.write_json(directory / "provenance.json", records)

    def test_selected_views_are_validated_as_a_set_and_scale_is_pointed_out(self):
        self.figure("e08_codex_1120", "br_la", {"south.png": 60, "east.png": 42, "west.png": 60, "north.png": 60})
        report = vb.run(self.art, ["e08_codex_1120"])
        figure = report["figures"][0]
        self.assertEqual(figure["id"], "br_la")
        self.assertEqual(sorted(figure["views"]), ["east", "north", "south", "west"])
        self.assertEqual(figure["status"], "warn")
        self.assertEqual(report["summary"]["scale_out_of_tolerance"][0]["view"], "east")
        self.assertEqual(report["summary"]["views_validated"], 4)

    def test_only_the_selected_version_of_each_view_is_validated(self):
        self.figure("e08_codex_1120", "x", {"south.png": 60, "east.png": 40, "east_v2.png": 60, "west.png": 60,
                                            "north.png": 60}, selected={"south.png", "east_v2.png", "west.png", "north.png"})
        figure = vb.run(self.art, ["e08_codex_1120"])["figures"][0]
        self.assertTrue(figure["sources"]["east"]["file"].endswith("east_v2.png"))
        self.assertEqual(figure["status"], "pass")

    def test_provenance_without_selected_uses_the_latest_version_and_says_so(self):
        self.figure("e08_codex_1116", "druid", {"south.png": 60, "east.png": 40, "east_v2.png": 60, "west.png": 60,
                                                "north.png": 60}, flag=False)
        figure = vb.run(self.art, ["e08_codex_1116"])["figures"][0]
        self.assertTrue(figure["sources"]["east"]["file"].endswith("east_v2.png"))
        self.assertTrue(figure["sources"]["east"]["inferred_latest_version"])

    def test_a_later_batch_replaces_a_view_of_an_earlier_one(self):
        self.figure("e08_codex_1121", "br_sp", {"south.png": 60, "east.png": 40, "west.png": 60, "north.png": 60})
        self.figure("e08_codex_1122", "br_sp", {"east_v2.png": 60})
        figure = vb.run(self.art, ["e08_codex_1121", "e08_codex_1122"])["figures"][0]
        self.assertEqual(figure["sources"]["east"]["batch"], "e08_codex_1122")
        self.assertEqual(figure["sources"]["south"]["batch"], "e08_codex_1121")
        self.assertEqual(figure["status"], "pass")

    def test_crop_overrides_from_the_v1_record_are_applied(self):
        files = {"south.png": 60, "east.png": 60, "west.png": 60, "north.png": 60}
        self.figure("e08_codex_1121", "a", files, overflow={"south.png": {14: 12}})
        first = vb.run(self.art, ["e08_codex_1121"])["figures"][0]
        self.assertEqual(first["status"], "fail")
        suggested = next(i for i in first["views"]["south"]["issues"]
                         if i["code"] == "no_gutter_band")["details"]["boundaries"][0]["suggested_crop_override"]
        self.figure("e08_codex_1121", "a", files, overflow={"south.png": {14: 12}},
                    overrides={"south.png": [suggested]})
        figure = vb.run(self.art, ["e08_codex_1121"])["figures"][0]
        self.assertEqual(figure["status"], "pass", figure["views"]["south"]["issues"])
        self.assertEqual(figure["views"]["south"]["measurements"]["boundary_overrides_applied"], [suggested])

    def test_equipment_sheets_use_the_declared_counts(self):
        directory = self.art / "e08_codex_1120/equipment"
        path = helpers.equipment_sheet(directory / "weapons_h1_v2.png", widths=(60, 80, 50))
        helpers.write_json(directory / "provenance.json", [
            helpers.v1_record("assets/art/e08_codex_1120/equipment/weapons_h1_v2.png", sha256_file(path),
                              width=500, height=120, selected=True)])
        sheet = vb.run(self.art, ["e08_codex_1120"], {"weapons_h1": 3})["sheets"][0]
        self.assertEqual(sheet["slot"], "weapons_h1")
        self.assertEqual(sheet["report"]["status"], "pass", sheet["report"]["issues"])
        sheet = vb.run(self.art, ["e08_codex_1120"], {"weapons_h1": 8})["sheets"][0]
        self.assertEqual(sheet["report"]["status"], "fail")

    def test_cli_summary_and_exit_code(self):
        self.figure("e08_codex_1120", "ok", {"south.png": 60, "east.png": 60, "west.png": 60, "north.png": 60})
        out = self.tmp / "report.json"
        code, stdout, _ = self.run_cli("validate_batch.py", "--art-root", self.art, "--batch", "e08_codex_1120",
                                       "--out", out)
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(stdout)["figures"], 1)
        self.assertEqual(json.loads(out.read_text(encoding="utf-8"))["schema"], vb.REPORT_SCHEMA)
        self.assertEqual(self.run_cli("validate_batch.py", "--art-root", self.art, "--batch", "nope")[0], 2)


if __name__ == "__main__":
    unittest.main()
