"""Scale normaliser: equalise the idle body height between the views of a figure (contract C5).

Generators drift in figure size from one view to the next (E08 1120: Sicário east 0.71 and west
0.78 of the south height). This tool scales a whole sheet so that its median idle height (row 1,
alpha bounding boxes, the statistic the directional packager uses) equals a reference height.

The default filter is `nearest`: no smoothing, no new colours, so pixel art stays pixel art. The
result has non-integer pixel ratios, which is the price of equalising; `--filter lanczos` is the
explicit, recorded alternative for art that is not pixel art. The sheet dimensions change with
the scale; the equal-division grid still holds because width and height scale together.
The step is returned in the `post` shape of ragrpg_art_provenance_v2.

    # one view against the reference view
    python tools/art_pipeline/normalize_scale.py --reference south.png east.png east_norm.png
    # a whole set, writing only the views that differ by more than --min-change
    python tools/art_pipeline/normalize_scale.py --set south=s.png east=e.png west=w.png north=n.png \
        --out-dir normalized/
Sheets need real alpha: run remove_background.py first for flat-colour backgrounds.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "art_pipeline"

from . import VERSION  # noqa: E402
from .common import PipelineError, emit_json, sha256_file  # noqa: E402
from .imaging import ALPHA_THRESHOLD, Image, load_rgba, np, save_png  # noqa: E402
from . import sheet_layout as layout  # noqa: E402

TOOL = "art_pipeline.normalize_scale"
FILTERS = {"nearest": Image.Resampling.NEAREST, "lanczos": Image.Resampling.LANCZOS}
DEFAULT_MIN_CHANGE = 0.02


def measure_idle_height(path_or_pixels, alpha_threshold=ALPHA_THRESHOLD, overrides=None):
    """Median idle body height in px of a view sheet with real alpha."""
    pixels = path_or_pixels if hasattr(path_or_pixels, "shape") else load_rgba(path_or_pixels)[0]
    mask = layout.content_mask(pixels[:, :, 3], alpha_threshold)
    height = layout.idle_height(layout.cell_boxes(mask, overrides=overrides))
    if not height:
        raise PipelineError("could not measure the idle height: the idle row is empty (is the background removed?)")
    return height


def scale_pixels(pixels, factor, resample="nearest"):
    if resample not in FILTERS:
        raise PipelineError("filter must be one of %s" % ", ".join(FILTERS))
    height, width = pixels.shape[:2]
    size = (max(1, round(width * factor)), max(1, round(height * factor)))
    image = Image.fromarray(pixels, "RGBA").resize(size, FILTERS[resample])
    result = np.array(image, dtype=np.uint8)
    result[result[:, :, 3] == 0, :3] = 0
    return result


def normalize_view(source, output, reference_height, filter_name="nearest", min_change=DEFAULT_MIN_CHANGE,
                   alpha_threshold=ALPHA_THRESHOLD, overrides=None, force=False):
    """Scale `source` so its idle height matches `reference_height`; write `output` if it changes.

    Returns a report with before/after heights and, when written, the provenance `post` step.
    """
    source, output = Path(source), Path(output)
    if source.resolve() == output.resolve():
        raise PipelineError("output must differ from input; sources are never overwritten")
    pixels, info = load_rgba(source)
    measured = measure_idle_height(pixels, alpha_threshold, overrides)
    factor = reference_height / measured
    report = {"input": str(source), "measured_idle_height_px": measured,
              "reference_idle_height_px": reference_height, "scale": round(factor, 6),
              "filter": filter_name, "changed": False}
    if abs(factor - 1.0) < min_change:
        report["note"] = "within +-%.0f%% of the reference; nothing written" % (100 * min_change)
        return report
    if output.exists() and not force:
        raise PipelineError("output exists; pass --force to replace it: %s" % output)
    scaled = scale_pixels(pixels, factor, filter_name)
    save_png(scaled, output)
    after = measure_idle_height(scaled, alpha_threshold)  # crop overrides are in source pixels: not carried over
    report.update(changed=True, output=str(output), input_size=[pixels.shape[1], pixels.shape[0]],
                  output_size=[scaled.shape[1], scaled.shape[0]], after_idle_height_px=after,
                  after_ratio=round(after / reference_height, 4))
    report["post"] = {
        "tool": TOOL, "version": VERSION,
        "params": {"reference_idle_height_px": reference_height, "measured_idle_height_px": measured,
                   "scale": round(factor, 6), "filter": filter_name, "smoothing": filter_name != "nearest",
                   "input_size": report["input_size"], "output_size": report["output_size"]},
        "input_sha256": sha256_file(source), "output_sha256": sha256_file(output),
    }
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description="Equalise idle body height between views (no smoothing by default).")
    parser.add_argument("sheet", nargs="?", help="single mode: the view to normalise")
    parser.add_argument("output", nargs="?", help="single mode: where to write it")
    parser.add_argument("--reference", help="single mode: reference view sheet (its idle height is the target)")
    parser.add_argument("--target-height", type=float, help="single mode: target idle height in px instead of --reference")
    parser.add_argument("--set", nargs="+", metavar="DIR=PATH", help="set mode: views of one figure")
    parser.add_argument("--reference-view", default="south", choices=layout.DIRECTIONS, help="set mode (default south)")
    parser.add_argument("--out-dir", help="set mode: folder for the normalised views (same file names)")
    parser.add_argument("--filter", choices=sorted(FILTERS), default="nearest")
    parser.add_argument("--min-change", type=float, default=DEFAULT_MIN_CHANGE,
                        help="skip views already within this fraction (default %(default)s)")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)
    try:
        reports = {}
        if args.set:
            if not args.out_dir:
                raise PipelineError("set mode needs --out-dir")
            views = {}
            for item in args.set:
                direction, _, value = item.partition("=")
                if direction not in layout.DIRECTIONS or not value:
                    raise PipelineError("--set entries look like south=path.png, got %r" % item)
                views[direction] = Path(value)
            if args.reference_view not in views:
                raise PipelineError("the reference view %r is not in --set" % args.reference_view)
            reference_height = measure_idle_height(views[args.reference_view])
            for direction, path in views.items():
                if direction == args.reference_view:
                    continue
                reports[direction] = normalize_view(path, Path(args.out_dir) / path.name, reference_height,
                                                    args.filter, args.min_change, force=args.force)
            result = {"reference_view": args.reference_view, "reference_idle_height_px": reference_height,
                      "views": reports}
        else:
            if not (args.sheet and args.output):
                raise PipelineError("give SHEET OUTPUT, or --set with --out-dir")
            if (args.reference is None) == (args.target_height is None):
                raise PipelineError("give exactly one of --reference or --target-height")
            reference_height = args.target_height if args.reference is None else measure_idle_height(args.reference)
            result = normalize_view(args.sheet, args.output, reference_height, args.filter, args.min_change,
                                    force=args.force)
        emit_json(result)
        return 0
    except PipelineError as error:
        sys.stderr.write("error: %s\n" % error)
        return 2


if __name__ == "__main__":
    sys.exit(main())
