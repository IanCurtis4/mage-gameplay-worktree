"""Validator for `ragrpg_source_sheet_v1` source sheets (contract C5). Read-only; JSON output.

Single sheet:
    python tools/art_pipeline/validate_sheet.py east.png --kind character_view --direction east
    python tools/art_pipeline/validate_sheet.py weapons.png --kind equipment_row --count 8
    python tools/art_pipeline/validate_sheet.py south_on_magenta.png --kind character_view \
        --background '#FF00FF'            # removal is done in memory, with the recorded parameters

Set of views (adds the cross-view scale check):
    python tools/art_pipeline/validate_sheet.py --set south=s.png east=e.png west=w.png north=n.png \
        --kind character_view --reference south --scale-tolerance 0.10

Every issue is {code, severity, message, details}. `error` fails the sheet; `warning` is reported
(a scale mismatch is a warning because tools/art_pipeline/normalize_scale.py fixes it; pass
--strict-scale to make it an error). Exit code 0 = pass/warn, 1 = fail, 2 = usage or unreadable file.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "art_pipeline"

from .common import PipelineError, emit_json, png_size, sha256_file, tool_stamp, write_json_atomic  # noqa: E402
from .imaging import ALPHA_THRESHOLD, color_hex, load_rgba, parse_color  # noqa: E402
from . import remove_background as bg  # noqa: E402
from . import sheet_layout as layout  # noqa: E402

REPORT_SCHEMA = "ragrpg_art_validation_report_v1"
DEFAULT_SPEC = {
    "schema": layout.SCHEMA,
    "alpha_threshold": ALPHA_THRESHOLD,
    "edge_margin": 1,           # content must stay >= this many px inside its cell
    "min_band": 8,              # a transparent gutter narrower than this is a warning
    "min_gap": 2,               # equipment: empty columns that separate two objects
    "min_object_pixels": 64,    # equipment: smaller blobs are specks, not objects
    "min_transparent_fraction": 0.25,
    "veil_warn_pixels": 500,
    "idle_spread_warn": 0.15,   # (max-min)/median of the four idle heights
    "scale_tolerance": 0.10,    # cross-view idle height tolerance (+-10%)
}


def make_spec(kind, direction=None, background=None, count=None, boundary_overrides=None, **overrides):
    """Build a sheet spec. `background` is None/'alpha' or a flat colour '#RRGGBB'.

    `boundary_overrides` moves a vertical cell boundary for one row, in the shape of the v1
    provenance `crop_overrides` ({"row", "boundary_after_column", "x_px"}).
    """
    if kind not in layout.KINDS:
        raise PipelineError("kind must be one of %s" % ", ".join(layout.KINDS))
    if direction is not None and direction not in layout.DIRECTIONS:
        raise PipelineError("direction must be one of %s" % ", ".join(layout.DIRECTIONS))
    spec = dict(DEFAULT_SPEC)
    spec.update({key: value for key, value in overrides.items() if value is not None})
    spec["kind"] = kind
    spec["direction"] = direction
    if background in (None, "alpha"):
        spec["background"] = {"mode": "alpha"}
    else:
        spec["background"] = {"mode": "flat", "color": color_hex(parse_color(background))}
    if count is not None:
        spec["expected_count"] = int(count)
    if boundary_overrides:
        spec["boundary_overrides"] = [dict(item) for item in boundary_overrides]
    return spec


def _issue(code, severity, message, **details):
    return {"code": code, "severity": severity, "message": message, "details": details}


def _status(issues, strict=False):
    if any(item["severity"] == "error" for item in issues):
        return "fail"
    if issues:
        return "fail" if strict else "warn"
    return "pass"


def _prepare_pixels(path, spec, issues):
    """Load the sheet; apply the declared flat-background removal in memory. Returns (pixels, meta)."""
    pixels, info = load_rgba(path)
    meta = {"mode": info["mode"], "format": info["format"]}
    background = spec["background"]
    if background["mode"] == "alpha":
        if info["mode"] != "RGBA":
            issues.append(_issue("not_rgba", "error",
                                 "sheet is %s, not RGBA; declare a flat background or export real alpha" % info["mode"],
                                 mode=info["mode"]))
        return pixels, meta
    # flat colour declared
    transparent = float((pixels[:, :, 3] == 0).mean())
    if info["has_alpha"] and transparent >= spec["min_transparent_fraction"]:
        issues.append(_issue("flat_declared_but_alpha_present", "warning",
                             "a flat background was declared but the sheet already has real alpha; "
                             "removal skipped", transparent_fraction=round(transparent, 4)))
        return pixels, meta
    key = parse_color(background["color"])
    params = {"tolerance": bg.DEFAULTS["tolerance"]}
    matches, worst = bg.corner_match(pixels, key, params["tolerance"])
    if not matches:
        issues.append(_issue("flat_background_mismatch", "error",
                             "corners/border are not within tolerance of the declared key colour",
                             key=color_hex(key), worst_corner_distance=worst,
                             tolerance=params["tolerance"]))
    cleaned, used, stats = bg.remove_flat_background(pixels, key)
    meta["background_removal"] = {"in_memory_only": True, "params": used, "stats": stats}
    return cleaned, meta


def validate_pixels(pixels, spec, issues, measurements):
    """Kind-specific checks on RGBA pixels already background-free."""
    alpha = pixels[:, :, 3]
    threshold = spec["alpha_threshold"]
    mask = layout.content_mask(alpha, threshold)
    height, width = mask.shape
    transparent = float((alpha <= threshold).mean())  # a faint veil still counts as transparent here
    measurements["transparent_fraction"] = round(transparent, 4)
    if spec["background"]["mode"] == "alpha" and transparent < spec["min_transparent_fraction"]:
        issues.append(_issue("background_not_transparent", "error",
                             "only %.1f%% of the pixels are fully transparent; the background is not alpha"
                             % (100 * transparent), transparent_fraction=round(transparent, 4)))
    veil = layout.veil_pixels(alpha, mask, threshold)
    measurements["veil_pixels"] = veil
    if veil > spec["veil_warn_pixels"]:
        issues.append(_issue("alpha_veil", "warning",
                             "%d faint pixels (alpha 1-%d) away from the figures; clear them with "
                             "remove_background --veil-alpha" % (veil, threshold),
                             veil_pixels=veil, alpha_threshold=threshold))
    kind = spec["kind"]
    if kind in layout.GRID_KINDS:
        _check_grid(mask, spec, issues, measurements)
    elif kind == "equipment_row":
        _check_equipment_row(mask, spec, issues, measurements)
    elif kind == "icon_source":
        _check_icon(mask, spec, issues, measurements, width, height)


def _check_grid(mask, spec, issues, measurements):
    cols, rows = layout.GRID
    overrides = spec.get("boundary_overrides") or None
    cells = layout.cell_boxes(mask, cols, rows, overrides)
    margin = spec["edge_margin"]
    empty = [cell["index"] for cell in cells if cell["bbox"] is None]
    touching = []
    for cell in cells:
        if cell["bbox"] is None:
            continue
        x0, y0, x1, y1 = cell["region"]
        bx0, by0, bx1, by1 = cell["bbox"]
        sides = [name for name, hit in (("left", bx0 - x0 < margin), ("top", by0 - y0 < margin),
                                        ("right", x1 - bx1 < margin), ("bottom", y1 - by1 < margin)) if hit]
        if sides:
            touching.append({"cell": cell["index"], "row": cell["row"] + 1, "col": cell["col"] + 1, "sides": sides})
    if empty:
        # An effect flipbook may legitimately end (or start) on a blank frame: a warning there.
        severity = "warning" if spec["kind"] == "vfx_source" else "error"
        issues.append(_issue("empty_cell", severity, "%d of %d cells are empty" % (len(empty), len(cells)),
                             cells=empty, expected=len(cells)))
    if touching:
        issues.append(_issue("touches_cell_edge", "error",
                             "%d cell(s) have content touching the cell border" % len(touching),
                             cells=touching, edge_margin=margin))
    bands = layout.gutter_bands(mask, cols, rows, overrides)
    broken, narrow = [], []
    for axis, matrix in bands.items():
        for line, widths in enumerate(matrix):
            for boundary, width in enumerate(widths):
                where = {"axis": axis, "row" if axis == "vertical" else "column": line + 1,
                         "boundary_after": boundary + 1, "band_px": width}
                if width == 0:
                    if axis == "vertical":
                        where["suggested_crop_override"] = layout.suggest_row_boundary(
                            mask, cols, rows, line, boundary + 1, overrides)
                    broken.append(where)
                elif width < spec["min_band"]:
                    narrow.append(where)
    if broken:
        issues.append(_issue("no_gutter_band", "error",
                             "content sits on %d cell boundary(ies): no transparent band separates the cells; for a "
                             "vertical one, suggested_crop_override is the cut the packager can use" % len(broken),
                             boundaries=broken))
    elif narrow:
        issues.append(_issue("narrow_gutter", "warning",
                             "%d transparent band(s) between cells are narrower than %d px" % (len(narrow), spec["min_band"]),
                             boundaries=narrow))
    measurements["sprite_count"] = sum(1 for cell in cells if cell["bbox"] is not None)
    measurements["expected_sprite_count"] = len(cells)
    measurements["gutter_band_min_px"] = min(
        (w for matrix in bands.values() for widths in matrix for w in widths), default=0)
    measurements["boundary_overrides_applied"] = list(overrides or [])
    measurements["cells"] = [{"index": c["index"], "bbox": c["bbox"]} for c in cells]
    if spec["kind"] == "vfx_source":
        return  # no idle row in an effect sheet
    heights = layout.idle_heights(cells, cols)
    measurements["idle_heights_px"] = heights
    measurements["idle_height_px"] = layout.idle_height(cells, cols)
    if len(heights) == cols and measurements["idle_height_px"]:
        median = measurements["idle_height_px"]
        spread = (max(heights) - min(heights)) / median
        measurements["idle_spread"] = round(spread, 4)
        if spread > spec["idle_spread_warn"]:
            issues.append(_issue("idle_height_spread", "warning",
                                 "the four idle poses differ by %.0f%% in height" % (100 * spread),
                                 heights=heights, spread=round(spread, 4)))


def _check_equipment_row(mask, spec, issues, measurements):
    height, width = mask.shape
    segments = layout.column_segments(mask, spec["min_gap"])
    objects, specks = [], []
    for x0, x1 in segments:
        sub = mask[:, x0:x1]
        pixels = int(sub.sum())
        bbox = layout.mask_bbox(sub)
        record = {"x0": x0, "x1": x1, "y0": bbox[1], "y1": bbox[3], "pixels": pixels}
        (objects if pixels >= spec["min_object_pixels"] else specks).append(record)
    for first, second in zip(objects, objects[1:]):
        second["gap_before_px"] = second["x0"] - first["x1"]
    measurements["objects"] = objects
    measurements["object_count"] = len(objects)
    if specks:
        issues.append(_issue("specks", "warning", "%d tiny blob(s) ignored as specks" % len(specks),
                             specks=specks, min_object_pixels=spec["min_object_pixels"]))
    expected = spec.get("expected_count")
    if expected is None:
        issues.append(_issue("expected_count_unknown", "warning",
                             "no --count given; found %d object(s)" % len(objects), found=len(objects)))
    elif len(objects) != expected:
        reason = ("objects touch or overlap in x (a gap below %d px merges them)" % spec["min_gap"]
                  if len(objects) < expected else "extra separated blobs")
        issues.append(_issue("object_count_mismatch", "error",
                             "expected %d separated objects, found %d: %s" % (expected, len(objects), reason),
                             expected=expected, found=len(objects), min_gap=spec["min_gap"]))
    margin = spec["edge_margin"]
    edge_hits = [o for o in objects if o["x0"] < margin or width - o["x1"] < margin
                 or o["y0"] < margin or height - o["y1"] < margin]
    if edge_hits:
        issues.append(_issue("touches_sheet_edge", "error", "%d object(s) touch the sheet border" % len(edge_hits),
                             objects=edge_hits))


def _check_icon(mask, spec, issues, measurements, width, height):
    if width != height:
        issues.append(_issue("icon_not_square", "error", "icon source must be square", width=width, height=height))
    if min(width, height) < layout.ICON_MIN_SIDE:
        issues.append(_issue("icon_too_small", "error",
                             "icon side must be at least %d px" % layout.ICON_MIN_SIDE, width=width, height=height))
    bbox = layout.mask_bbox(mask)
    if bbox is None:
        issues.append(_issue("icon_empty", "error", "the icon has no content"))
        return
    measurements["content_bbox"] = bbox
    margin = spec["edge_margin"]
    if bbox[0] < margin or bbox[1] < margin or width - bbox[2] < margin or height - bbox[3] < margin:
        issues.append(_issue("touches_sheet_edge", "error", "icon content touches the border", bbox=bbox))


def validate_sheet(path, spec):
    """Validate one sheet; returns a report dict. Never writes."""
    issues = []
    path = Path(path)
    report = {"schema": REPORT_SCHEMA, "tool": tool_stamp("art_pipeline.validate_sheet"),
              "scope": "sheet", "spec": spec}
    if not path.is_file():
        issues.append(_issue("file_missing", "error", "file not found", path=str(path)))
        report.update(sheet={"path": str(path)}, issues=issues, measurements={}, status="fail")
        return report
    try:
        width, height = png_size(path)
    except PipelineError as error:
        issues.append(_issue("not_png", "error", str(error)))
        report.update(sheet={"path": str(path)}, issues=issues, measurements={}, status="fail")
        return report
    sheet = {"path": str(path).replace("\\", "/"), "sha256": sha256_file(path), "width": width, "height": height}
    measurements = {}
    pixels, meta = _prepare_pixels(path, spec, issues)
    sheet.update(meta)
    validate_pixels(pixels, spec, issues, measurements)
    report.update(sheet=sheet, issues=issues, measurements=measurements, status=_status(issues))
    return report


def validate_set(views, spec, reference="south", scale_tolerance=None, strict_scale=False):
    """Validate several views of one figure and compare their idle body heights.

    `views` maps direction -> path, or direction -> (path, boundary_overrides) when a view needs
    the v1 `crop_overrides`. Ratios are height(view) / height(reference).
    """
    tolerance = spec["scale_tolerance"] if scale_tolerance is None else scale_tolerance
    reports = {}
    for direction, entry in views.items():
        path, overrides = entry if isinstance(entry, tuple) else (entry, None)
        view_spec = dict(spec)
        view_spec["direction"] = direction
        if overrides:
            view_spec["boundary_overrides"] = [dict(item) for item in overrides]
        reports[direction] = validate_sheet(path, view_spec)
    set_issues = []
    ratios = {}
    reference_height = None
    if reference in reports:
        reference_height = reports[reference]["measurements"].get("idle_height_px")
    if reference not in views:
        set_issues.append(_issue("reference_missing", "error", "reference view %r not supplied" % reference))
    elif not reference_height:
        set_issues.append(_issue("reference_unmeasurable", "error",
                                 "idle height of the reference view could not be measured", reference=reference))
    else:
        for direction, view_report in reports.items():
            height = view_report["measurements"].get("idle_height_px")
            if direction == reference or not height:
                continue
            ratio = height / reference_height
            ratios[direction] = round(ratio, 3)
            if abs(ratio - 1.0) > tolerance:
                set_issues.append(_issue(
                    "scale_mismatch", "error" if strict_scale else "warning",
                    "%s idle body is %.0f%% of the %s height (tolerance +-%.0f%%); "
                    "normalize_scale suggests x%.3f" % (direction, 100 * ratio, reference, 100 * tolerance,
                                                         1 / ratio),
                    view=direction, ratio=round(ratio, 3), deviation_pct=round(100 * (ratio - 1), 1),
                    tolerance_pct=round(100 * tolerance, 1), suggested_scale=round(1 / ratio, 4)))
    all_issues = list(set_issues)
    for view_report in reports.values():
        all_issues.extend(view_report["issues"])
    return {
        "schema": REPORT_SCHEMA, "tool": tool_stamp("art_pipeline.validate_sheet"), "scope": "set",
        "spec": spec, "reference_view": reference,
        "scale": {"reference_idle_height_px": reference_height, "ratios": ratios,
                  "tolerance": tolerance, "worst_deviation_pct": (
                      max((abs(r - 1) for r in ratios.values()), default=0) * 100)},
        "views": reports, "set_issues": set_issues,
        "status": _status(all_issues), "summary": summarize(all_issues),
    }


def summarize(issues):
    counts = {}
    for item in issues:
        counts[item["code"]] = counts.get(item["code"], 0) + 1
    return {"errors": sum(1 for i in issues if i["severity"] == "error"),
            "warnings": sum(1 for i in issues if i["severity"] == "warning"), "by_code": counts}


def _parse_set(items):
    views = {}
    for item in items:
        if "=" not in item:
            raise PipelineError("--set entries look like south=path.png, got %r" % item)
        direction, value = item.split("=", 1)
        if direction not in layout.DIRECTIONS:
            raise PipelineError("unknown direction %r" % direction)
        views[direction] = value
    return views


def build_parser():
    parser = argparse.ArgumentParser(description="Validate ragrpg_source_sheet_v1 source sheets (read-only).")
    parser.add_argument("sheet", nargs="?", help="a single sheet; use --set for several views")
    parser.add_argument("--set", nargs="+", metavar="DIR=PATH", help="views of one figure, e.g. south=s.png east=e.png")
    parser.add_argument("--kind", required=True, choices=layout.KINDS)
    parser.add_argument("--direction", choices=layout.DIRECTIONS, help="single sheet: which view this is")
    parser.add_argument("--background", default="alpha", help="alpha (default) or a flat key colour, e.g. '#FF00FF'")
    parser.add_argument("--count", type=int, help="equipment_row: how many objects the row holds")
    parser.add_argument("--reference", default="south", choices=layout.DIRECTIONS)
    parser.add_argument("--scale-tolerance", type=float, default=None,
                        help="fraction of the reference idle height, default 0.10 (plus or minus 10 percent)")
    parser.add_argument("--strict-scale", action="store_true", help="a scale mismatch fails the set")
    parser.add_argument("--strict", action="store_true", help="warnings also fail (exit 1)")
    parser.add_argument("--alpha-threshold", type=int, default=None)
    parser.add_argument("--edge-margin", type=int, default=None)
    parser.add_argument("--min-band", type=int, default=None)
    parser.add_argument("--out", help="write the JSON report here instead of stdout")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        spec = make_spec(args.kind, args.direction, args.background, args.count,
                         alpha_threshold=args.alpha_threshold, edge_margin=args.edge_margin,
                         min_band=args.min_band)
        if args.set:
            report = validate_set(_parse_set(args.set), spec, args.reference, args.scale_tolerance, args.strict_scale)
        elif args.sheet:
            report = validate_sheet(args.sheet, spec)
        else:
            raise PipelineError("give a sheet or --set")
    except PipelineError as error:
        sys.stderr.write("error: %s\n" % error)
        return 2
    if args.out:
        write_json_atomic(args.out, report)
    else:
        emit_json(report)
    failed = report["status"] == "fail" or (args.strict and report["status"] == "warn")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
