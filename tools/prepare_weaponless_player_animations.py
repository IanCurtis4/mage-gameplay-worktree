"""Normalize original ImageGen weaponless sheets without touching historical atlases."""
from hashlib import sha256
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/animation_sources/fixes_mobs/player_weaponless"
STAGING = ROOT / ".godot/verification/fixes_art/weaponless_pipeline"
NAMES = ("swordsman", "archer", "berserker", "defender", "elementalist", "hunter", "mage", "sentinel", "spiritualist", "geometer")


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def main() -> None:
    spec = importlib.util.spec_from_file_location("shared_animation_pipeline", ROOT / "tools/prepare_animation_assets.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("Shared animation preparation pipeline could not be loaded")
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    STAGING.mkdir(parents=True, exist_ok=True)
    pipeline.SOURCE = STAGING
    pipeline.DEST = STAGING
    report = {}
    candidates = {}
    for name in NAMES:
        source = SOURCE / f"{name}_weaponless_source.png"
        if not source.exists():
            raise FileNotFoundError(source)
        source_hash = digest(source)
        image = Image.open(source).convert("RGBA")
        if image.width / image.height != 0.5:
            raise ValueError(f"{name}: expected a 4x8 source sheet, got {image.size}")
        # Split the 4x8 image into two 4x4 sources for the shared pipeline.
        for half, suffix in ((0, ""), (1, "_extra")):
            top = round(half * image.height / 2)
            bottom = round((half + 1) * image.height / 2)
            image.crop((0, top, image.width, bottom)).save(STAGING / f"{name}_unarmed{suffix}.png")
        prepared = pipeline.prepare(f"{name}_unarmed")
        atlas_path = STAGING / f"{name}_unarmed.png"
        atlas = Image.open(atlas_path).convert("RGBA")
        frames = [atlas.crop((i % 4 * 64, i // 4 * 64, (i % 4 + 1) * 64, (i // 4 + 1) * 64)) for i in range(32)]
        unique = {sha256(frame.tobytes()).hexdigest() for frame in frames}
        if atlas.size != (256, 512) or len(unique) != 32:
            raise ValueError(f"{name}: normalized atlas must contain 32 distinct 64px cells; got {atlas.size}, {len(unique)}/32")
        if any(frame.getchannel("A").getbbox() is None for frame in frames):
            raise ValueError(f"{name}: normalized atlas contains an empty frame")
        target = ROOT / "assets/art/animations" / f"{name}_weaponless.png"
        candidates[name] = (atlas_path, target)
        alpha = np.asarray(atlas.getchannel("A"))
        report[name] = {
            "source": str(source.relative_to(ROOT)),
            "source_sha256": source_hash,
            "source_size": list(image.size),
            "atlas": str(target.relative_to(ROOT)),
            "atlas_sha256": digest(atlas_path),
            "size": list(atlas.size),
            "frames": len(frames),
            "unique_frames": len(unique),
            "cell": 64,
            "pivot": [32, 58],
            "scale": prepared["scale"],
            "transparent_pixel_fraction": float(np.count_nonzero(alpha == 0) / alpha.size),
            "opaque_pixel_fraction": float(np.count_nonzero(alpha == 255) / alpha.size),
            "frame_bounds": prepared["frame_bounds"],
        }
        if digest(source) != source_hash:
            raise ValueError(f"{name}: source image changed during preparation")
    for source_path, target in candidates.values():
        target.write_bytes(source_path.read_bytes())
    out = ROOT / ".godot/verification/fixes_art"
    out.mkdir(parents=True, exist_ok=True)
    report_path = out / "weaponless_atlas_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(report_path)
    for name, item in report.items():
        print(name, item["atlas_sha256"], f"{item['unique_frames']}/32 unique", item["size"], item["transparent_pixel_fraction"])


if __name__ == "__main__":
    main()
