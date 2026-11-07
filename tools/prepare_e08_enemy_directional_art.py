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
}


def native_idle_height(visual_id):
    source = Image.open(ROOT / "assets/art/animations" / (visual_id + ".png")).convert("RGBA")
    heights = []
    for index in range(4):
        box = source.crop((index * 64, 0, index * 64 + 64, 64)).getchannel("A").getbbox()
        if box is None:
            raise ValueError("Native idle cell is empty")
        heights.append(box[3] - box[1])
    return float(statistics.median(heights))


def build(visual_id, recipe):
    if recipe.get("visual_id") != visual_id or recipe.get("actor_kind") != KINDS[visual_id]:
        raise ValueError("Recipe visual identity/kind mismatch")
    # No assumptions about humanoid size for a gel or a quadruped.
    expected_height = native_idle_height(visual_id)
    if "target_height" in recipe and float(recipe["target_height"]) != expected_height:
        raise ValueError("Target height must match the native idle median")
    recipe = dict(recipe, target_height=expected_height)
    spec = importlib.util.spec_from_file_location("e08_art_packer", ROOT / "tools/prepare_e08_directional_art.py")
    packer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packer)
    folder = ROOT / "assets/art/e08_enemies/directional" / visual_id
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
    manifest = {
        "format": "ragrpg_directional_animation_v2", "actor_kind": KINDS[visual_id], "pivot": [32, 58],
        "body": {"path": "res://assets/art/e08_enemies/directional/" + visual_id + "/body.png",
                 "rgba_sha256": report["rgba_sha256"]}, "weaponless": None, "frames": frames,
    }
    calibration = {"visual_id": visual_id, "actor_kind": KINDS[visual_id],
                   "authored_rgba_sha256": report["rgba_sha256"], "equipment_rig": "unused_baked_npc_props",
                   "head_attachment": "unused", "frames": frames}
    report.update(visual_id=visual_id, actor_kind=KINDS[visual_id], native_idle_height=expected_height,
                  direction_sha256=blocks, mode="authored_unequipped_npc_unit")
    return atlas, manifest, calibration, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("visual_id", choices=tuple(KINDS))
    args = parser.parse_args()
    folder = ROOT / "assets/art/e08_enemies/directional" / args.visual_id
    recipe = json.loads((folder / "source_recipe.json").read_text(encoding="utf-8"))
    atlas, manifest, calibration, report = build(args.visual_id, recipe)
    atlas.save(folder / "body.png")
    for name, value in (("presentation.json", manifest), ("calibration.json", calibration)):
        (folder / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
