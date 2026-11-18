"""E10a T9: cut the three approved family objects into runtime props and 128 px icons.

Sources (read only, versioned by E10a T2): equipment sheets with real alpha. Each object is found
as the N-th run of alpha>16 columns (1-indexed, left to right), exactly as the E08 selection
records name them. Crop/scale/pack only, no repainting. Deterministic.
Outputs: props/<id>.png (logical size x4, RGBA), icons/equipment/painted/<id>.png (128x128),
manifest.json with hashes. Run with plain `python` from the repository root.
"""
from pathlib import Path
import hashlib, json, sys
sys.dont_write_bytecode = True
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/art/e10a_equipment"
ICONS = ROOT / "assets/art/icons/equipment/painted"
THRESH = 16
SCALE = 4
SOURCES = {
    "prayer_book": ("assets/art/e08_codex_1118/equipment/weapons_b1.png", 1, (20, 30)),
    "halo_scepter": ("assets/art/e08_codex_1118/equipment/weapons_b1.png", 2, (15, 42)),
    "eye_reliquary": ("assets/art/e08_codex_1118/equipment/weapons_b1.png", 3, (14, 38)),
}

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def bleed(image, iterations=12):
    data = np.array(image, dtype=np.uint8); known = data[..., 3] > 0
    rgb = data[..., :3].astype(np.float64); rgb[~known] = 0.0; h, w = known.shape
    for _ in range(iterations):
        if known.all() or not known.any(): break
        pr = np.pad(rgb * known[..., None], ((1, 1), (1, 1), (0, 0))); pk = np.pad(known.astype(np.float64), 1)
        total = np.zeros_like(rgb); count = np.zeros(known.shape)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0: continue
                total += pr[1+dy:1+dy+h, 1+dx:1+dx+w]; count += pk[1+dy:1+dy+h, 1+dx:1+dx+w]
        fill = (~known) & (count > 0); rgb[fill] = total[fill] / count[fill][:, None]; known |= fill
    data[..., :3] = np.clip(np.rint(rgb), 0, 255).astype(np.uint8)
    return Image.fromarray(data, "RGBA")

def object_box(alpha, index):
    cols = (alpha > THRESH).any(0); runs = []; start = None
    for x, v in enumerate(cols):
        if v and start is None: start = x
        if not v and start is not None: runs.append((start, x)); start = None
    if start is not None: runs.append((start, len(cols)))
    x0, x1 = runs[index - 1]
    rows = np.where((alpha[:, x0:x1] > THRESH).any(1))[0]
    return (x0, int(rows.min()), x1, int(rows.max()) + 1), len(runs)

def main():
    manifest = {"schema": "e10a_equipment_art_v1", "items": []}
    for item_id, (rel, index, logical) in SOURCES.items():
        sheet = Image.open(ROOT / rel).convert("RGBA")
        box, count = object_box(np.array(sheet)[..., 3], index)
        obj = sheet.crop(box)
        arr = np.array(obj); arr[arr[..., 3] <= THRESH] = 0; obj = Image.fromarray(arr, "RGBA")  # clear the faint veil
        w, h = obj.size
        # Prop: fit inside logical*4 keeping aspect, centred, bottom-anchored not needed (centred).
        pw, ph = logical[0] * SCALE, logical[1] * SCALE
        fit = min((pw - 4) / w, (ph - 4) / h)  # 2 px clear margin on every side
        nw, nh = max(1, round(w * fit)), max(1, round(h * fit))
        prop = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
        small = bleed(obj.resize((nw, nh), Image.LANCZOS))
        prop.paste(small, ((pw - nw) // 2, (ph - nh) // 2))
        prop.save(OUT / "props" / (item_id + ".png"), optimize=True)
        side = max(w, h); sq = Image.new("RGBA", (side, side), (0, 0, 0, 0)); sq.paste(obj, ((side - w) // 2, (side - h) // 2))
        icon = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        inner = bleed(sq.resize((118, 118), Image.LANCZOS)); icon.paste(inner, (5, 5))
        icon = bleed(icon); icon.save(ICONS / (item_id + ".png"), optimize=True)
        manifest["items"].append({"id": item_id, "source": rel, "source_sha256": sha(ROOT / rel), "object_index": index,
            "objects_in_sheet": count, "box": list(box), "prop_png": "props/%s.png" % item_id, "prop_size": [pw, ph],
            "prop_sha256": sha(OUT / "props" / (item_id + ".png")), "icon_png": "icons/equipment/painted/%s.png" % item_id,
            "icon_sha256": sha(ICONS / (item_id + ".png")), "post": [{"tool": "assets/art/e10a_equipment/prepare_e10a_equipment.py", "params": {"clear_alpha_at_or_below": THRESH, "lanczos": True, "bleed_iterations": 12}}]})
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

main()
