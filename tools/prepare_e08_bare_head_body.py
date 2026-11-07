"""Validate a closed head-only art recipe and reuse the proven Mage compositor."""
from pathlib import Path
import argparse
import importlib.util
import json
import math
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
KINDS = ("archer", "hunter", "sentinel", "geometer")


def validate(kind, data, folder):
    if data.get("actor_kind") != kind:
        raise ValueError("Head art identity mismatch")
    frames = data.get("frames", [])
    if len(frames) != 64 or sorted(f.get("index", -1) for f in frames) != list(range(64)):
        raise ValueError("Exactly64 unique authored frames required")
    for frame in frames:
        source = (folder / frame["source"]).resolve()
        if source.parent != folder.resolve() or source.suffix.lower() != ".png":
            raise ValueError("Head sources must be local PNGs in this unit")
        if not source.is_file():
            raise ValueError("Head source missing")
        pose = frame.get("source_cell")
        if not isinstance(pose, int) or not 0 <= pose < 16:
            raise ValueError("Source cell must refer to4x4 sheet")
        for rect in [frame["head_region"], *frame.get("protections", [])]:
            if (len(rect) != 4 or not all(isinstance(x, int) for x in rect)
                    or not 0 <= rect[0] < rect[2] <= 64 or not 0 <= rect[1] < rect[3] <= 64):
                raise ValueError("Authored region/protection outside64cell")
        for name in ("head_anchor", "offset"):
            point = frame.get(name, [])
            if len(point) != 2 or not all(isinstance(x, int) for x in point):
                raise ValueError("Authored integer head point/offset required")
            limit = range(64) if name == "head_anchor" else range(-63, 64)
            if any(x not in limit for x in point):
                raise ValueError("Head point/offset outside unit limits")
        angle = frame.get("head_angle")
        if not isinstance(angle, (int, float)) or not math.isfinite(angle) or abs(angle) > math.tau:
            raise ValueError("Authored finite head angle required")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("actor_kind", choices=KINDS)
    args = parser.parse_args()
    folder = ROOT / "assets/art/e08_head_fit" / args.actor_kind
    data = json.loads((folder / "calibration.json").read_text(encoding="utf-8"))
    validate(args.actor_kind, data, folder)
    # Import has a main guard. Only this module instance's paths are assigned;
    # the shared Mage source file and Mage art are never modified.
    spec = importlib.util.spec_from_file_location("closed_mage_head_compositor", ROOT / "tools/prepare_e08_mage_bare_head.py")
    compositor = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(compositor)
    compositor.D = folder
    compositor.ORIGINAL = ROOT / "assets/art/e08_characters/directional" / args.actor_kind / "body.png"
    compositor.RIG = compositor.ORIGINAL.parent / "calibration.json"
    compositor.main()


if __name__ == "__main__":
    main()
