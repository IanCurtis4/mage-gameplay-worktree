"""Flat-colour background removal (contract C5).

For generators that cannot give real alpha (Gemini/Nano Banana, some ComfyUI workflows) and
paint the figures on a flat key colour such as #FF00FF or #00FF00. The tool

1. marks every pixel within `tolerance` (euclidean RGB distance) of the key as background,
   either everywhere (`global`, default) or only where connected to the image border
   (`connected`, for figures that legitimately contain a key-like colour);
2. cleans the anti-aliased fringe: for `edge_steps` rings next to the background, a pixel whose
   colour is closer to the key than to its most figure-like neighbour (blend < 50%) becomes
   background, and the others are recoloured to that neighbour, which removes the key-coloured
   halo while keeping the pixel art crisp (alpha stays binary);
3. optionally clears a faint alpha veil (`veil_alpha`).

Background pixels end as RGBA (0,0,0,0). The parameters used are returned (and printed by the
CLI) in the shape of a `post` step of ragrpg_art_provenance_v2. Nothing is smoothed or resized.

    python tools/art_pipeline/remove_background.py in.png out.png --key '#FF00FF' [--tolerance 48]
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
from .imaging import color_hex, load_rgba, np, parse_color, save_png  # noqa: E402

TOOL = "art_pipeline.remove_background"
DEFAULTS = {"tolerance": 48.0, "mode": "global", "edge_steps": 1, "veil_alpha": 0}


def _distance_squared(rgb, key):
    delta = rgb.astype(np.int32) - np.array(key, dtype=np.int32)
    return (delta * delta).sum(axis=2)


def _dilate4(mask):
    out = mask.copy()
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def border_connected(candidate):
    """Candidate pixels 4-connected to the image border (iterative dilation, no scipy)."""
    reach = np.zeros_like(candidate)
    reach[0, :] = candidate[0, :]
    reach[-1, :] = candidate[-1, :]
    reach[:, 0] = candidate[:, 0]
    reach[:, -1] = candidate[:, -1]
    while True:
        grown = _dilate4(reach) & candidate
        if np.array_equal(grown, reach):
            return reach
        reach = grown


def corner_match(pixels, key, tolerance):
    """True when the four corners and the border median are within `tolerance` of the key."""
    rgb = pixels[:, :, :3]
    border = np.concatenate([rgb[0, :], rgb[-1, :], rgb[:, 0], rgb[:, -1]])
    median = np.median(border, axis=0)
    corners = [rgb[0, 0], rgb[0, -1], rgb[-1, 0], rgb[-1, -1]]
    key_array = np.array(key, dtype=np.float64)
    distances = [float(np.linalg.norm(corner.astype(np.float64) - key_array)) for corner in corners]
    distances.append(float(np.linalg.norm(median - key_array)))
    return max(distances) <= tolerance, round(max(distances), 1)


def remove_flat_background(pixels, key, tolerance=None, mode=None, edge_steps=None, veil_alpha=None):
    """Return (RGBA pixels, params dict, stats dict). `pixels` is HxWx4 uint8 and is not modified."""
    tolerance = DEFAULTS["tolerance"] if tolerance is None else float(tolerance)
    mode = DEFAULTS["mode"] if mode is None else mode
    edge_steps = DEFAULTS["edge_steps"] if edge_steps is None else int(edge_steps)
    veil_alpha = DEFAULTS["veil_alpha"] if veil_alpha is None else int(veil_alpha)
    if mode not in ("global", "connected"):
        raise PipelineError("mode must be global or connected")
    if tolerance < 0 or edge_steps < 0 or not 0 <= veil_alpha <= 255:
        raise PipelineError("tolerance, edge_steps and veil_alpha must be non-negative (veil_alpha <= 255)")
    out = pixels.copy()
    rgb = out[:, :, :3]
    distance2 = _distance_squared(rgb, key)
    candidate = distance2 <= tolerance * tolerance
    background = border_connected(candidate) if mode == "connected" else candidate
    key_array = np.array(key, dtype=np.int32)
    height, width = background.shape
    ring_pixels = 0
    for _ in range(edge_steps):
        edge = _dilate4(background) & ~background
        if not edge.any():
            break
        interior = ~background & ~edge
        # Most figure-like (farthest from the key) interior neighbour of each edge pixel.
        best_distance = np.full((height, width), -1, dtype=np.int32)
        best_color = np.zeros((height, width, 3), dtype=np.uint8)
        padded_interior = np.pad(interior, 1, constant_values=False)
        padded_rgb = np.pad(rgb, ((1, 1), (1, 1), (0, 0)))
        padded_distance = np.pad(distance2, 1)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                n_interior = padded_interior[1 + dy:1 + dy + height, 1 + dx:1 + dx + width]
                n_distance = padded_distance[1 + dy:1 + dy + height, 1 + dx:1 + dx + width]
                n_rgb = padded_rgb[1 + dy:1 + dy + height, 1 + dx:1 + dx + width]
                better = n_interior & (n_distance > best_distance)
                best_distance = np.where(better, n_distance, best_distance)
                best_color = np.where(better[:, :, None], n_rgb, best_color)
        has_neighbor = edge & (best_distance >= 0)
        # blend fraction of the figure colour in the pixel: |c-key| / |fg-key|
        own = np.sqrt(distance2.astype(np.float64))
        figure = np.sqrt(np.maximum(best_distance, 1).astype(np.float64))
        fraction = np.where(has_neighbor, own / figure, 1.0)
        to_background = edge & (fraction < 0.5)
        snap = has_neighbor & ~to_background & (distance2 > 0)
        rgb[snap] = best_color[snap]
        background = background | to_background
        ring_pixels += int(to_background.sum() + snap.sum())
    alpha = out[:, :, 3]
    if veil_alpha:
        veil = (alpha > 0) & (alpha <= veil_alpha) & ~background
        alpha[veil] = 0
        background = background | veil
    out[background] = 0
    params = {
        "key": color_hex(key),
        "tolerance": tolerance,
        "mode": mode,
        "edge_steps": edge_steps,
        "veil_alpha": veil_alpha,
        "alpha_output": "binary where the input had no alpha; input alpha kept elsewhere",
    }
    stats = {
        "background_pixels": int(background.sum()),
        "background_fraction": round(float(background.mean()), 4),
        "edge_pixels_processed": ring_pixels,
        "remaining_key_like_pixels": int(((distance2 <= tolerance * tolerance) & ~background).sum()),
    }
    return out, params, stats


def post_step(input_path, output_path, params, stats=None):
    step = {
        "tool": TOOL,
        "version": VERSION,
        "params": params,
        "input_sha256": sha256_file(input_path),
        "output_sha256": sha256_file(output_path),
    }
    if stats is not None:
        step["stats"] = stats
    return step


def main(argv=None):
    parser = argparse.ArgumentParser(description="Remove a flat-colour background and write an RGBA PNG.")
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--key", required=True, help="background colour: #RRGGBB or r,g,b")
    parser.add_argument("--tolerance", type=float, default=DEFAULTS["tolerance"],
                        help="euclidean RGB distance treated as background (default %(default)s)")
    parser.add_argument("--mode", choices=("global", "connected"), default=DEFAULTS["mode"],
                        help="global: every key-like pixel; connected: only regions touching the border")
    parser.add_argument("--edge-steps", type=int, default=DEFAULTS["edge_steps"],
                        help="rings of anti-aliased fringe to clean (default %(default)s, 0 disables)")
    parser.add_argument("--veil-alpha", type=int, default=DEFAULTS["veil_alpha"],
                        help="also clear alpha at or below this value (default %(default)s = off)")
    parser.add_argument("--emit-post", help="write the provenance post step to this JSON file")
    parser.add_argument("--force", action="store_true", help="overwrite an existing, different output")
    args = parser.parse_args(argv)
    try:
        source = Path(args.input)
        target = Path(args.output)
        if target.resolve() == source.resolve():
            raise PipelineError("output must differ from input; sources are never overwritten")
        if target.exists() and not args.force:
            raise PipelineError("output exists; pass --force to replace it: %s" % target)
        pixels, info = load_rgba(source)
        key = parse_color(args.key)
        matches, worst = corner_match(pixels, key, args.tolerance)
        result, params, stats = remove_flat_background(pixels, key, args.tolerance, args.mode,
                                                       args.edge_steps, args.veil_alpha)
        save_png(result, target)
        step = post_step(source, target, params, stats)
        report = {"input": str(source), "output": str(target), "corners_match_key": matches,
                  "worst_corner_distance": worst, "post": step}
        if args.emit_post:
            from .common import write_json_atomic
            write_json_atomic(args.emit_post, step)
        emit_json(report)
        return 0 if matches else 2
    except PipelineError as error:
        sys.stderr.write("error: %s\n" % error)
        return 1


if __name__ == "__main__":
    sys.exit(main())
