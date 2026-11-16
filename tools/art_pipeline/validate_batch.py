"""Validate a whole staging batch laid out like assets/art/e08_codex_*/ (read-only; JSON report).

For every figure folder (`characters/<id>/`, `creatures/<id>/`) it reads the provenance file
(v1 or v2), picks the chosen file of each of the four views, validates the set with the
cross-view scale check, and honours the v1 `crop_overrides` the packager already uses. Equipment
and vfx sheets are validated one by one.

Which file counts as the chosen one of a view:
  1. the record with `selected: true`;
  2. if the provenance never recorded `selected` (round 1116): the highest `_vN` (flagged "inferred");
  3. later batches on the command line replace earlier ones view by view (1122 corrects 1121).

    python tools/art_pipeline/validate_batch.py --art-root <repo>/.tools/map-editor-m5/assets/art \
        --batch e08_codex_1120 --batch e08_codex_1121 --batch e08_codex_1122 --batch e08_codex_1123 \
        --equipment-count weapons_h1=8 --equipment-count weapons_h2=8 --out report.json
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "art_pipeline"

from .common import PipelineError, emit_json, posix, tool_stamp, write_json_atomic  # noqa: E402
from .provenance import load_provenance  # noqa: E402
from .selection import slot_name, version_number  # noqa: E402
from . import sheet_layout as layout  # noqa: E402
from . import validate_sheet as vs  # noqa: E402

REPORT_SCHEMA = "ragrpg_art_batch_report_v1"
FIGURE_FOLDERS = {"characters": "character_view", "creatures": "creature_view"}
SHEET_FOLDERS = {"equipment": "equipment_row", "vfx": "vfx_source"}


def choose_views(provenance):
    """{direction: {path, sha256, selected, inferred, crop_overrides}} for one figure folder."""
    chosen = {}
    has_info = provenance.has_selection_info()
    by_view = {}
    for record in provenance.records:
        slot = slot_name(record["path"])
        if slot in layout.DIRECTIONS:
            by_view.setdefault(slot, []).append(record)
    for view, records in by_view.items():
        picked = [r for r in records if r["selected"] is True]
        inferred = False
        if len(picked) > 1:
            raise PipelineError("%s: two selected files for view %s" % (provenance.path, view))
        if not picked:
            if has_info:
                continue  # selection info exists and this view has no chosen file
            picked = [max(records, key=lambda r: version_number(r["path"]))]
            inferred = True
        record = picked[0]
        chosen[view] = {"record": record, "inferred": inferred}
    return chosen


def _compact_view(view_name, info, located):
    record = info["record"]
    return {"file": posix(located), "sha256": record["sha256"], "selected": record["selected"],
            "inferred_latest_version": info["inferred"]}


def run(art_root, batches, equipment_counts=None, background="alpha"):
    art_root = Path(art_root)
    equipment_counts = equipment_counts or {}
    figures = {}      # (folder, id) -> {"views": {direction: {...}}, "sources": [...]}
    sheets = []       # single sheets
    skipped = []
    for batch in batches:
        batch_dir = art_root / batch
        if not batch_dir.is_dir():
            raise PipelineError("batch folder not found: %s" % batch_dir)
        for folder in sorted(p for p in batch_dir.iterdir() if p.is_dir()):
            if folder.name in FIGURE_FOLDERS:
                for figure_dir in sorted(p for p in folder.iterdir() if p.is_dir() and (p / "provenance.json").is_file()):
                    provenance = load_provenance(figure_dir / "provenance.json")
                    entry = figures.setdefault((folder.name, figure_dir.name), {"views": {}})
                    for view, info in choose_views(provenance).items():
                        located, _how = provenance.resolve(info["record"])
                        if located is None:
                            located = figure_dir / Path(info["record"]["path"]).name
                        if not located.is_file():
                            raise PipelineError("chosen file is missing: %s" % located)
                        entry["views"][view] = {"path": located, "batch": batch, "info": info,
                                                "overrides": info["record"].get("legacy", {}).get("crop_overrides")}
            elif folder.name in SHEET_FOLDERS and (folder / "provenance.json").is_file():
                provenance = load_provenance(folder / "provenance.json")
                has_info = provenance.has_selection_info()
                by_slot = {}
                for record in provenance.records:
                    by_slot.setdefault(slot_name(record["path"]), []).append(record)
                for slot, records in sorted(by_slot.items()):
                    picked = [r for r in records if r["selected"] is True]
                    inferred = False
                    if not picked:
                        if has_info:
                            continue
                        picked = [max(records, key=lambda r: version_number(r["path"]))]
                        inferred = True
                    record = picked[0]
                    path = folder / Path(record["path"]).name
                    spec = vs.make_spec(SHEET_FOLDERS[folder.name], background=background,
                                        count=equipment_counts.get(slot))
                    report = vs.validate_sheet(path, spec)
                    sheets.append({"batch": batch, "folder": folder.name, "slot": slot, "file": posix(path),
                                   "selected": record["selected"], "inferred_latest_version": inferred,
                                   "report": report})
            elif folder.name not in FIGURE_FOLDERS:
                skipped.append({"batch": batch, "folder": folder.name, "reason": "no validator for this folder kind"})
    figure_reports = []
    for (folder_name, figure_id), entry in sorted(figures.items(), key=lambda item: (item[1]["views"].get("south", {}).get("batch", ""), item[0][1])):
        views = {view: (data["path"], data["overrides"]) for view, data in entry["views"].items()}
        report = vs.validate_set(views, vs.make_spec(FIGURE_FOLDERS[folder_name], background=background))
        report["id"] = figure_id
        report["folder"] = folder_name
        report.pop("tool", None)
        report["sources"] = {view: {"batch": data["batch"], **_compact_view(view, data["info"], data["path"])}
                             for view, data in entry["views"].items()}
        figure_reports.append(report)
    return {"schema": REPORT_SCHEMA, "tool": tool_stamp("art_pipeline.validate_batch"),
            "art_root_hint": posix(art_root), "batches": list(batches), "figures": figure_reports,
            "sheets": sheets, "skipped": skipped, "summary": summarize(figure_reports, sheets)}


def summarize(figure_reports, sheets):
    scale_out, code_counts = [], {}
    status_counts = {"pass": 0, "warn": 0, "fail": 0}
    view_total = 0
    for figure in figure_reports:
        status_counts[figure["status"]] += 1
        for view, report in figure["views"].items():
            view_total += 1
            for item in report["issues"]:
                code_counts[item["code"]] = code_counts.get(item["code"], 0) + 1
        for item in figure["set_issues"]:
            code_counts[item["code"]] = code_counts.get(item["code"], 0) + 1
            if item["code"] == "scale_mismatch":
                scale_out.append({"figure": figure["id"], "view": item["details"]["view"],
                                  "ratio": item["details"]["ratio"],
                                  "deviation_pct": item["details"]["deviation_pct"]})
    sheet_status = {"pass": 0, "warn": 0, "fail": 0}
    for sheet in sheets:
        sheet_status[sheet["report"]["status"]] += 1
        for item in sheet["report"]["issues"]:
            code_counts[item["code"]] = code_counts.get(item["code"], 0) + 1
    scale_out.sort(key=lambda row: -abs(row["deviation_pct"]))
    return {"figures": len(figure_reports), "views_validated": view_total, "figure_status": status_counts,
            "sheets": len(sheets), "sheet_status": sheet_status, "issue_counts": dict(sorted(code_counts.items())),
            "scale_out_of_tolerance": scale_out,
            "worst_scale_deviation_pct": max((abs(r["deviation_pct"]) for r in scale_out), default=0)}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Validate staged art batches (read-only).")
    parser.add_argument("--art-root", required=True, help="folder holding e08_codex_*/ (assets/art)")
    parser.add_argument("--batch", action="append", required=True, help="batch folder name; later ones override earlier")
    parser.add_argument("--equipment-count", action="append", default=[], metavar="SLOT=N",
                        help="objects expected in an equipment sheet, e.g. weapons_h1=8")
    parser.add_argument("--background", default="alpha")
    parser.add_argument("--out", help="write the JSON report here instead of stdout")
    parser.add_argument("--summary-only", action="store_true", help="print only the summary to stdout")
    args = parser.parse_args(argv)
    try:
        counts = {}
        for item in args.equipment_count:
            slot, _, number = item.partition("=")
            counts[slot] = int(number)
        report = run(args.art_root, args.batch, counts, args.background)
    except (PipelineError, ValueError) as error:
        sys.stderr.write("error: %s\n" % error)
        return 2
    if args.out:
        write_json_atomic(args.out, report)
    if args.summary_only or args.out:
        emit_json(report["summary"])
    else:
        emit_json(report)
    return 1 if report["summary"]["figure_status"]["fail"] or report["summary"]["sheet_status"]["fail"] else 0


if __name__ == "__main__":
    sys.exit(main())
