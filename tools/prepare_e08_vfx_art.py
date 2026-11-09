"""E08 P6-B1: package the Codex VFX flipbook sheets into 160x160-cell atlases.

Pipeline per sheet (1254x1254 RGBA, 4x4 grid, only crop/scale/pack, no repainting):
  1. slice 16 cells with exact rounded boundaries round(i*W/4);
  2. ONE common alpha bbox (alpha > 8) over all 16 frames so the effect stays
     registered frame to frame; every frame is cropped to that bbox;
  3. the bbox is padded to a square centred on the bbox centre and resized once with
     LANCZOS (Pillow premultiplies RGBA for resampling, so no dark halos) into the
     inner 156x156 area of a 160x160 cell (2 px transparent margin on every side so
     linear filtering and mipmaps never bleed into the neighbour cell);
  4. RGB of fully transparent pixels is filled by alpha bleed (dilation of the
     neighbouring opaque colour); alpha is never changed;
  5. 4x4 atlas 640x640 + flipbook.json + staging/provenance.json.
Deterministic; never writes inside the staging folder except provenance.json.
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
STAGING = ROOT / "assets/art/e08_vfx/staging"
OUT = ROOT / "assets/art/e08_vfx"
IDS = ("arcane_warp", "blood_rift", "fire_burst", "ground_shockwave", "ice_shatter",
       "lightning_burst", "nature_thorns", "slash_arc", "summon_portal")
FPS = {"slash_arc": 16, "lightning_burst": 16, "summon_portal": 10, "nature_thorns": 10}
GRID = 4
CELL = 160
MARGIN = 2
ALPHA_THRESHOLD = 8
BLEED_ITERATIONS = 24


def sha256_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rgba_hash(image):
    data = np.array(image.convert("RGBA"), dtype=np.uint8)
    data[data[..., 3] == 0, :3] = 0
    return hashlib.sha256(data.tobytes()).hexdigest()


def bleed(image):
    """Fill RGB of alpha==0 pixels from neighbouring coloured pixels; alpha untouched."""
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


def slice_cells(sheet):
    width, height = sheet.size
    cells = []
    for row in range(GRID):
        for col in range(GRID):
            box = (round(col * width / GRID), round(row * height / GRID),
                   round((col + 1) * width / GRID), round((row + 1) * height / GRID))
            cells.append(sheet.crop(box))
    return cells


def alpha_bbox(cell):
    mask = np.array(cell.getchannel("A")) > ALPHA_THRESHOLD
    if not mask.any():
        return None
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def package(effect_id):
    source = STAGING / (effect_id + ".png")
    sheet = Image.open(source).convert("RGBA")
    cells = slice_cells(sheet)
    boxes = [alpha_bbox(cell) for cell in cells]
    filled = [box for box in boxes if box is not None]
    x0 = min(b[0] for b in filled)
    y0 = min(b[1] for b in filled)
    x1 = max(b[2] for b in filled)
    y1 = max(b[3] for b in filled)
    # Square window centred on the common bbox centre; any excess is transparent padding.
    side = max(x1 - x0, y1 - y0)
    left = int(round((x0 + x1) / 2.0 - side / 2.0))
    top = int(round((y0 + y1) / 2.0 - side / 2.0))
    inner = CELL - 2 * MARGIN
    atlas = Image.new("RGBA", (CELL * GRID, CELL * GRID), (0, 0, 0, 0))
    peak_index, peak_area = 0, -1
    for index, cell in enumerate(cells):
        window = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        window.paste(cell.crop((left, top, left + side, top + side)), (0, 0))
        frame = window.resize((inner, inner), Image.LANCZOS)
        atlas.paste(frame, ((index % GRID) * CELL + MARGIN, (index // GRID) * CELL + MARGIN))
        area = int((np.array(cell.getchannel("A")) > ALPHA_THRESHOLD).sum())
        if area > peak_area:
            peak_index, peak_area = index, area
    alpha = np.array(atlas.getchannel("A"))
    atlas = bleed(atlas)
    empty = []
    for index in range(GRID * GRID):
        col, row = index % GRID, index // GRID
        block = alpha[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL]
        if not (block > ALPHA_THRESHOLD).any():
            empty.append(index)
    peak_box = boxes[peak_index]
    peak_width = (peak_box[2] - peak_box[0]) * inner / side
    out_dir = OUT / effect_id
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / "flipbook.png"
    if STAGING in target.resolve().parents:
        raise SystemExit("refusing to write into staging")
    atlas.save(target, optimize=False)
    sidecar = {
        "id": effect_id,
        "revision": 1,
        "source": "assets/art/e08_vfx/staging/%s.png" % effect_id,
        "source_sha256": sha256_file(source),
        "texture": "res://assets/art/e08_vfx/%s/flipbook.png" % effect_id,
        "grid": [GRID, GRID],
        "cell": [CELL, CELL],
        "frames": GRID * GRID,
        "empty_frames": empty,
        # bbox centre == packed cell centre: the visual centre of these 3/4-view
        # effects is the ground point.
        "anchor_uv": [0.5, 0.5],
        "suggested_fps": FPS.get(effect_id, 12),
        "loop": False,
        # width of the peak frame's visible content (alpha > 8) in packed cell pixels:
        # drawing a cell at 1 px = 1 world unit yields this diameter; consumers scale
        # by wanted_diameter / world_diameter_hint.
        "world_diameter_hint": round(peak_width, 1),
        "source_common_bbox": [x0, y0, x1, y1],
        "source_window": [left, top, side],
        "peak_frame": peak_index,
        "rgba_sha256": rgba_hash(atlas),
        "png_sha256": sha256_file(target),
    }
    (out_dir / "flipbook.json").write_text(json.dumps(sidecar, indent=2) + "\n", encoding="utf-8", newline="\n")
    return sidecar


def write_provenance():
    assets = {}
    for effect_id in IDS:
        path = STAGING / (effect_id + ".png")
        image = Image.open(path)
        assets[effect_id] = {
            "path": "assets/art/e08_vfx/staging/%s.png" % effect_id,
            "sha256": sha256_file(path),
            "width": image.width,
            "height": image.height,
            "generator": "Codex built-in imagegen",
            "request": "docs/epics/e08_p6_imagegen_briefs.md §%s" % effect_id,
            "prompt": None,
            "prompt_note": "prompt exato não registrado (usuário dispensou provenance do Codex)",
            "rights_basis": "project_generated_output",
            "status": "generated_project_art_prompt_unrecorded",
        }
    (STAGING / "provenance.json").write_text(
        json.dumps({"assets": assets}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def main():
    for effect_id in IDS:
        report = package(effect_id)
        print(effect_id, report["empty_frames"], report["world_diameter_hint"], report["rgba_sha256"][:12])
    write_provenance()


if __name__ == "__main__":
    main()
