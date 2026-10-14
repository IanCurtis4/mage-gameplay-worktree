"""Prepare the three authorized E06 source sheets with the shared atlas pipeline."""
from hashlib import sha256
import importlib.util
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/animation_sources/fixes_mobs"
NAMES = ("gel", "beast_master", "animal_companion")


def remove_connected_matte(image: Image.Image) -> Image.Image:
    """Remove only border-connected neutral gray checker pixels from generated sheets."""
    rgba = np.asarray(image.convert("RGBA")).copy()
    rgb = rgba[:, :, :3].astype(np.int16)
    neutral = (rgb.min(axis=2) >= 120) & ((rgb.max(axis=2) - rgb.min(axis=2)) <= 16)
    height, width = neutral.shape
    seen = np.zeros(neutral.shape, dtype=np.bool_)
    queue = deque()
    for x in range(width):
        if neutral[0, x]: queue.append((0, x))
        if neutral[height - 1, x]: queue.append((height - 1, x))
    for y in range(height):
        if neutral[y, 0]: queue.append((y, 0))
        if neutral[y, width - 1]: queue.append((y, width - 1))
    while queue:
        y, x = queue.popleft()
        if seen[y, x] or not neutral[y, x]:
            continue
        seen[y, x] = True
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                ny, nx = y + dy, x + dx
                if 0 <= ny < height and 0 <= nx < width and not seen[ny, nx] and neutral[ny, nx]:
                    queue.append((ny, nx))
    rgba[seen, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def main() -> None:
    spec = importlib.util.spec_from_file_location("shared_animation_pipeline", ROOT / "tools/prepare_animation_assets.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("Shared animation preparation pipeline could not be loaded")
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    pipeline.SOURCE = SOURCE
    pipeline.remove_matte = remove_connected_matte

    report = {}
    for name in NAMES:
        sources = [SOURCE / f"{name}.png", SOURCE / f"{name}_extra.png"]
        preserved_sources = sorted(SOURCE.glob(f"{name}*.png"))
        before = {str(path.relative_to(ROOT)): digest(path) for path in preserved_sources}
        prepared = pipeline.prepare(name)
        atlas_path = ROOT / "assets/art/animations" / f"{name}.png"
        image = Image.open(atlas_path).convert("RGBA")
        frames = [image.crop((index % 4 * 64, index // 4 * 64, (index % 4 + 1) * 64, (index // 4 + 1) * 64)) for index in range(32)]
        hashes = {sha256(frame.tobytes()).hexdigest() for frame in frames}
        if image.size != (256, 512) or prepared["frames"] != 32:
            raise ValueError(f"{name}: expected a 256x512 atlas with 32 frames")
        if len(hashes) != 32:
            raise ValueError(f"{name}: repeated final frames detected ({len(hashes)}/32 unique)")
        if any(frame.getchannel("A").getbbox() is None for frame in frames):
            raise ValueError(f"{name}: empty frame detected")
        alpha_values = np.asarray(image.getchannel("A"))
        after = {str(path.relative_to(ROOT)): digest(path) for path in preserved_sources}
        if before != after:
            raise ValueError(f"{name}: source sheets changed during preparation")
        report[name] = {
            "all_source_sha256": before,
            "atlas": str(atlas_path.relative_to(ROOT)),
            "atlas_sha256": digest(atlas_path),
            "size": list(image.size),
            "frames": len(frames),
            "unique_frames": len(hashes),
            "cell": 64,
            "pivot": [32, 58],
            "groups": {"front_idle": [0, 1, 2, 3], "front_walk": [4, 5, 6, 7], "front_attack": [8, 9, 10, 11], "back_walk": [12, 13, 14, 15], "back_idle": [16, 17, 18, 19], "back_attack": [20, 21, 22, 23], "front_hurt": [24, 25], "back_hurt": [26, 27], "front_death": [28, 29], "back_death": [30, 31]},
            "transparent_pixel_fraction": float(np.count_nonzero(alpha_values == 0) / alpha_values.size),
            "opaque_pixel_fraction": float(np.count_nonzero(alpha_values == 255) / alpha_values.size),
            "scale": prepared["scale"],
            "opaque_bounds": prepared["frame_bounds"],
            "source_sizes": prepared["source_sizes"],
        }
    out = ROOT / ".godot/verification/fixes_art"
    out.mkdir(parents=True, exist_ok=True)
    target = out / "animation_atlas_report.json"
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(target)
    for name, item in report.items():
        print(name, item["atlas_sha256"], f"{item['unique_frames']}/32 unique", item["size"])


if __name__ == "__main__":
    main()
