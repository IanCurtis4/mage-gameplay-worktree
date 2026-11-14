"""E08 C1-art (14/11): cut the Codex painted equipment icon sheets into per-item icons.

Sources (read only): assets/art/e08_codex_1114/equipment_icons/*.png, RGBA 1254x1254, one
piece per grid cell in the order of docs/epics/e08_codex_art_1114_brief.md (section B).
Pipeline per piece, crop/scale/pack only, no repainting:
  1. split the sheet into its grid (2x1 for set sheets, 3x2 for the others) with exact
     rounded boundaries; every piece must stay inside its cell (checked);
  2. alpha bbox (alpha > 16) of the cell, then a square window centred on that bbox;
  3. one LANCZOS resize so the longer side fills INNER px of a SIZE px icon (so every
     icon reads at the same weight in the inventory), centred;
  4. alpha bleed of fully transparent RGB (no dark halo under linear filtering).
Output: assets/art/icons/equipment/painted/<item_id>.png and manifest.json (source and
output hashes, cell, bbox, prompt reference). Deterministic; never writes to the sources.
Run with plain `python` (Pillow lives in the user site).
"""
from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/e08_codex_1114/equipment_icons"
OUT = ROOT / "assets/art/icons/equipment/painted"
SIZE = 128
INNER = 118
ALPHA_THRESHOLD = 16
BLEED_ITERATIONS = 12
CLASSES = ("swordsman", "mage", "archer", "defender", "berserker", "elementalist",
           "spiritualist", "mg_ar", "sentinel", "hunter")
SHEETS = {}
for name in CLASSES:
    SHEETS["class_set_%s" % name] = ((2, 1), ["class_set_%s_torso" % name, "class_set_%s_feet" % name])
for level in ("low", "mid", "high"):
    SHEETS["shared_set_%s" % level] = ((2, 1), ["shared_set_%s_torso" % level, "shared_set_%s_feet" % level])
SHEETS["arena_torso"] = ((3, 2), ["arena_traveler_vest", "arena_trailcoat", "arena_channeler_robe",
                                  "arena_warden_mail", "arena_epic_ward", "arena_legendary_ward"])
SHEETS["jewelry"] = ((3, 2), ["arena_traveler_charm", "arena_prismatic_charm", "pilot_sp_jewel",
                              "pilot_stride_jewel", "pilot_ward_jewel", "pilot_step_neck"])
SHEETS["body_pieces"] = ((3, 2), ["pilot_shoulders", "pilot_arms", "pilot_cloak",
                                  "pilot_legs", "pilot_feet", "spiritualist_prayer_beads"])


def sha256_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def bleed(image):
    data = np.array(image, dtype=np.uint8)
    known = data[..., 3] > 0
    rgb = data[..., :3].astype(np.float64)
    rgb[~known] = 0.0
    h, w = known.shape
    for _ in range(BLEED_ITERATIONS):
        if known.all() or not known.any():
            break
        padded_rgb = np.pad(rgb * known[..., None], ((1, 1), (1, 1), (0, 0)))
        padded_known = np.pad(known.astype(np.float64), 1)
        total = np.zeros_like(rgb)
        count = np.zeros(known.shape)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                total += padded_rgb[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
                count += padded_known[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
        fill = (~known) & (count > 0)
        rgb[fill] = total[fill] / count[fill][:, None]
        known = known | fill
    data[..., :3] = np.clip(np.rint(rgb), 0, 255).astype(np.uint8)
    return Image.fromarray(data, "RGBA")


def cut(sheet_name, grid, ids):
    source = SOURCE / (sheet_name + ".png")
    sheet = Image.open(source).convert("RGBA")
    width, height = sheet.size
    cols, rows = grid
    entries = []
    for index, item_id in enumerate(ids):
        col, row = index % cols, index // cols
        box = (round(col * width / cols), round(row * height / rows),
               round((col + 1) * width / cols), round((row + 1) * height / rows))
        cell = sheet.crop(box)
        mask = np.array(cell.getchannel("A")) > ALPHA_THRESHOLD
        if not mask.any():
            raise SystemExit("%s: empty cell for %s" % (sheet_name, item_id))
        ys, xs = np.where(mask)
        x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
        if x0 == 0 or y0 == 0 or x1 == cell.width or y1 == cell.height:
            raise SystemExit("%s: %s touches its cell edge" % (sheet_name, item_id))
        side = max(x1 - x0, y1 - y0)
        left = int(round((x0 + x1) / 2.0 - side / 2.0))
        top = int(round((y0 + y1) / 2.0 - side / 2.0))
        window = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        window.paste(cell.crop((left, top, left + side, top + side)), (0, 0))
        icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        offset = (SIZE - INNER) // 2
        icon.paste(window.resize((INNER, INNER), Image.LANCZOS), (offset, offset))
        icon = bleed(icon)
        target = OUT / (item_id + ".png")
        icon.save(target, optimize=False)
        entries.append({
            "id": item_id,
            "file": target.name,
            "source": source.relative_to(ROOT).as_posix(),
            "source_sha256": sha256_file(source),
            "cell": list(box),
            "bbox_in_cell": [x0, y0, x1, y1],
            "png_sha256": sha256_file(target),
        })
    return entries


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    items = []
    for sheet_name, (grid, ids) in SHEETS.items():
        items.extend(cut(sheet_name, grid, ids))
    manifest = {
        "tool": "tools/prepare_e08_equipment_icons.py",
        "generator": "Codex built-in imagegen",
        "request": "docs/epics/e08_codex_art_1114_brief.md section B",
        "prompts": "assets/art/e08_codex_1114/equipment_icons/provenance.json",
        "rights_basis": "project_generated_output",
        "size": SIZE,
        "items": items,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(len(items), "icons")


if __name__ == "__main__":
    main()
