"""E10a T16 (A15): reduce the Livro de Orações prop to about 16x24 logical units.

Input : assets/art/e10a_equipment/prayer_book_full.png (the T9 prop, 80x120, SHA256 recorded in manifest.json).
Output: assets/art/e10a_equipment/props/prayer_book.png (64x96 = logical 16x24 x4).
Method: nearest-neighbour resample (no smoothing, no repainting, no new generation). Deterministic: every output pixel
is the input pixel at floor((x + 0.5) * 80 / 64) (PIL `Image.NEAREST` on the exact box). The step is appended to the
`post` list of the prayer_book item in manifest.json, with input and output hashes. Run from the repository root:
    python assets/art/e10a_equipment/prayer_book_reduce.py
"""
from pathlib import Path
import hashlib, json, sys
sys.dont_write_bytecode = True
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/art/e10a_equipment"
LOGICAL = (16, 24)
SCALE = 4
FULL_SHA256 = "5a9b433e9f48fa5c6fe5cb8a1a331d9d11083daad9e947c38f70eb7cd01de84e"

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    source = OUT / "prayer_book_full.png"
    if sha(source) != FULL_SHA256: raise SystemExit("prayer_book_full.png changed: expected the T9 prop")
    image = Image.open(source).convert("RGBA")
    size = (LOGICAL[0] * SCALE, LOGICAL[1] * SCALE)
    reduced = image.resize(size, Image.NEAREST)
    target = OUT / "props/prayer_book.png"
    reduced.save(target, optimize=True)
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for item in manifest["items"]:
        if item["id"] != "prayer_book": continue
        item["prop_size"] = list(size)
        item["prop_sha256"] = sha(target)
        item["post"] = [step for step in item["post"] if step.get("tool") != "assets/art/e10a_equipment/prayer_book_reduce.py"]
        item["post"].append({"tool": "assets/art/e10a_equipment/prayer_book_reduce.py", "version": "e10a-t16",
                              "params": {"filter": "nearest", "smoothing": False, "from_size": list(image.size), "to_size": list(size),
                                         "logical_size": list(LOGICAL), "decision": "A15 item 2 of docs/epics/e10a.md"},
                              "input": "assets/art/e10a_equipment/prayer_book_full.png", "input_sha256": FULL_SHA256,
                              "output_sha256": item["prop_sha256"]})
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(target, size, sha(target))

main()
