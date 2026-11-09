"""Pack authored NPC views using the existing E08 art pipeline, not a drawing tool."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import statistics
import sys

sys.dont_write_bytecode = True
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
KINDS = {
    "warrior": "warrior",
    "beast_master": "beast_master",
    "gel": "gel",
    "animal_companion": "animal_companion",
    "e08_forest_wolf": "animal_companion",
    "e08_forest_boar": "animal_companion",
    "e08_forest_stalker": "warrior",
    "e08_forest_canopy_archer": "archer",
    "e08_forest_warden": "beast_master",
}
# P5 B1 species: all four views are generated sheets (no native V1 atlas), so the
# recipe declares "generated_views": true and an explicit target_height.
GENERATED_VIEWS = ("south", "north", "east", "west")


def native_idle_height(visual_id):
    source = Image.open(ROOT / "assets/art/animations" / (visual_id + ".png")).convert("RGBA")
    heights = []
    for index in range(4):
        box = source.crop((index * 64, 0, index * 64 + 64, 64)).getchannel("A").getbbox()
        if box is None:
            raise ValueError("Native idle cell is empty")
        heights.append(box[3] - box[1])
    return float(statistics.median(heights))


def measure_hands(atlas, frames):
    """Measure two palm points per pose from skin-toned pixels of the art (no drawing).

    Candidates are skin-toned connected components outside the head zone (upper half of
    the pose box, within 7px of the head centre). main_hand is the bow-side one (largest x for east/south, smallest for
    west/north: a geometric convention, not an anatomical claim); off_hand the other.
    Without two components both fall back to the nearest glove-toned/any opaque pixel.
    Death poses (14/15 of each view) are exempt in the loader but still get opaque points.
    """
    import numpy as np
    from collections import deque
    data = np.array(atlas)
    for index, frame in enumerate(frames):
        view = index // 16
        tile = data[index // 4 * 64:index // 4 * 64 + 64, index % 4 * 64:index % 4 * 64 + 64]
        alpha = tile[:, :, 3] > 127
        ys, xs = np.where(alpha)
        top, bottom = ys.min(), ys.max()
        head_limit = top + 0.47 * (bottom - top + 1)
        r, g, b = (tile[:, :, i].astype(int) for i in range(3))
        skin = alpha & (r >= 190) & (r > g + 20) & (g > b + 10) & (g >= 130)
        head_cx = xs[ys < top + 0.2 * (bottom - top + 1)].mean()
        head_limit = top + 0.5 * (bottom - top + 1)
        seen = np.zeros_like(skin)
        comps = []
        for sy, sx in np.argwhere(skin):
            if seen[sy, sx]:
                continue
            queue, comp = deque([(sy, sx)]), []
            seen[sy, sx] = True
            while queue:
                y, x = queue.popleft()
                comp.append((y, x))
                for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                    if 0 <= ny < 64 and 0 <= nx < 64 and skin[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((ny, nx))
            cy, cx = np.mean(comp, axis=0)
            # The face is the skin blob under the head centre; drop it (poses 0-13 only).
            if index % 16 < 14 and cy < head_limit and abs(cx - head_cx) < 7:
                continue
            if len(comp) >= 3:
                comps.append(comp)
        comps.sort(key=lambda c: -len(c))
        picks = []
        for comp in comps[:2]:
            cy, cx = np.mean(comp, axis=0)
            picks.append(min(comp, key=lambda p: (p[0] - cy) ** 2 + (p[1] - cx) ** 2))
        if not picks:
            # No skin visible (e.g. hands hidden): nearest opaque pixel to the mid-body.
            mid = (int((top + bottom) / 2), int(xs.mean()))
            picks.append(min(zip(ys, xs), key=lambda p: (p[0] - mid[0]) ** 2 + (p[1] - mid[1]) ** 2))
        if len(picks) == 1:
            picks.append(picks[0])
        picks.sort(key=lambda p: p[1], reverse=view in (0, 2))  # south/east: bow-side = largest x first
        for slot, (py, px) in zip(("main_hand", "off_hand"), picks):
            x0, y0 = max(0, min(int(px) - 1, 61)), max(0, min(int(py) - 1, 61))
            frame["slots"][slot]["point"] = [int(px), int(py)]
            frame["slots"][slot]["fingers"] = [x0, y0, 3, 3]
        frame["slots"]["arms"]["point"] = [int((picks[0][1] + picks[1][1]) // 2), int((picks[0][0] + picks[1][0]) // 2)]


def build_per_view(packer, folder, recipe):
    """Generated sheets differ in figure size per view: pack each view with its own
    idle-median scale (each run packs one view into all four slots; block d of run d is
    kept). Still only crop/matte/scale/pack; one view cannot shrink another."""
    atlas = Image.new("RGBA", (256, 1024))
    scales, records = [], []
    for index, direction in enumerate(GENERATED_VIEWS):
        single = dict(recipe, views={name: recipe["views"][direction] for name in GENERATED_VIEWS})
        block, part = packer.build_unit(folder, single)
        atlas.paste(block.crop((0, index * 256, 256, index * 256 + 256)), (0, index * 256))
        scales.append(part["scale"])
        records.extend(dict(frame, direction=direction) for frame in part["frames"][index * 16:index * 16 + 16])
    pixels = bytearray(atlas.tobytes())
    for offset in range(0, len(pixels), 4):
        if pixels[offset + 3] == 0:
            pixels[offset:offset + 3] = bytes(3)
    return atlas, {"scale": scales, "rgba_sha256": hashlib.sha256(pixels).hexdigest(), "frames": records}


def build(visual_id, recipe):
    if recipe.get("visual_id") != visual_id or recipe.get("actor_kind") != KINDS[visual_id]:
        raise ValueError("Recipe visual identity/kind mismatch")
    generated = bool(recipe.get("generated_views", False))
    if generated:
        # Mechanical crop/matte/scale/pack of four generated sheets; the height is explicit.
        if "target_height" not in recipe or not 8 <= float(recipe["target_height"]) <= 56:
            raise ValueError("Generated-view recipes need an explicit target_height in [8,56]")
        for view in GENERATED_VIEWS:
            if recipe["views"][view].get("native_cells", False) or "indices" in recipe["views"][view]:
                raise ValueError("Generated-view recipes accept only generated 4x4 sheets")
        expected_height = float(recipe["target_height"])
    else:
        # No assumptions about humanoid size for a gel or a quadruped.
        expected_height = native_idle_height(visual_id)
        if "target_height" in recipe and float(recipe["target_height"]) != expected_height:
            raise ValueError("Target height must match the native idle median")
        recipe = dict(recipe, target_height=expected_height)
    spec = importlib.util.spec_from_file_location("e08_art_packer", ROOT / "tools/prepare_e08_directional_art.py")
    packer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packer)
    folder = ROOT / "assets/art/e08_enemies/directional" / visual_id
    if generated and recipe.get("per_view_scale", False):
        atlas, report = build_per_view(packer, folder, recipe)
    else:
        atlas, report = packer.build_unit(folder, recipe)
    blocks = [hashlib.sha256(atlas.crop((0, i * 256, 256, (i + 1) * 256)).tobytes()).hexdigest() for i in range(4)]
    if len(set(blocks)) != 4:
        raise ValueError("Four distinct authored direction blocks required")
    frames = []
    for index in range(64):
        tile = atlas.crop((index % 4 * 64, index // 4 * 64, index % 4 * 64 + 64, index // 4 * 64 + 64))
        box = tile.getchannel("A").getbbox()
        # These bodies use baked NPC props. Slots below are deliberately unused;
        # they are format placeholders, not a claim of an authored hand rig.
        frames.append({
            "ground_y": box[3] - 1,
            "slots": {slot: {"point": [32, 32], "fingers": [0, 0, 1, 1], "angle": 0.0,
                             "depth": 0, "flip": False} for slot in ("main_hand", "off_hand", "arms")},
            "head": {"point": [32, 24], "angle": 0.0, "depth": 1, "flip": False, "visible": False},
        })
    if generated and KINDS[visual_id] == "archer":
        # The loader treats the archer kind as equipable: hand pixels must be real.
        measure_hands(atlas, frames)
    manifest = {
        "format": "ragrpg_directional_animation_v2", "actor_kind": KINDS[visual_id], "pivot": [32, 58],
        "body": {"path": "res://assets/art/e08_enemies/directional/" + visual_id + "/body.png",
                 "rgba_sha256": report["rgba_sha256"]}, "weaponless": None, "frames": frames,
    }
    if generated and KINDS[visual_id] == "archer":
        # Weapon is embedded in the art: weaponless is the same pixels in its own file
        # (the loader forbids sharing one path between body and weaponless).
        manifest["weaponless"] = {"path": "res://assets/art/e08_enemies/directional/" + visual_id + "/weaponless.png",
                                  "rgba_sha256": report["rgba_sha256"]}
    calibration = {"visual_id": visual_id, "actor_kind": KINDS[visual_id],
                   "authored_rgba_sha256": report["rgba_sha256"], "equipment_rig": "unused_baked_npc_props",
                   "head_attachment": "unused", "frames": frames}
    if generated and KINDS[visual_id] == "archer":
        calibration["equipment_rig"] = "embedded_weapon_measured_hands_unprojected"
    report.update(visual_id=visual_id, actor_kind=KINDS[visual_id], native_idle_height=expected_height,
                  direction_sha256=blocks, mode="authored_unequipped_npc_unit")
    return atlas, manifest, calibration, report


def write_generated_provenance(folder, visual_id, recipe, report):
    """Input hashes and request; the exact Codex prompt was not recorded and is NOT invented here."""
    sources = {}
    for view in GENERATED_VIEWS:
        path = ROOT / recipe["views"][view]["source"][len("res://"):]
        sources[view] = {"path": str(path.relative_to(ROOT)).replace("\\", "/"),
                         "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "prompt": None}
    record = {"author": "Codex (imagegen)", "generator": "Codex built-in imagegen",
              "provenance": "generated_project_art_prompt_unrecorded",
              "request": "docs/epics/e08_p5_imagegen_briefs.md §1 (species)",
              "prompt_note": "exact prompt not recorded: user asked Codex to minimize tokens (2026-11-08)",
              "rights_basis": "project_generated_output",
              "sources": sources, "packer": "tools/prepare_e08_enemy_directional_art.py",
              "rgba_sha256": report["rgba_sha256"], "scale": report["scale"],
              "target_height": recipe["target_height"], "native_review": "pending"}
    (folder / "provenance.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("visual_id", choices=tuple(KINDS))
    args = parser.parse_args()
    folder = ROOT / "assets/art/e08_enemies/directional" / args.visual_id
    recipe = json.loads((folder / "source_recipe.json").read_text(encoding="utf-8"))
    atlas, manifest, calibration, report = build(args.visual_id, recipe)
    atlas.save(folder / "body.png")
    if manifest["weaponless"] is not None:
        atlas.save(folder / "weaponless.png")
    if recipe.get("generated_views"):
        write_generated_provenance(folder, args.visual_id, recipe, report)
    for name, value in (("presentation.json", manifest), ("calibration.json", calibration)):
        (folder / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
