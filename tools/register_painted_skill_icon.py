"""Register one original generated PNG without altering its pixels; checkpoint each asset."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/art/skills/painted"
QUEUE = ROOT / "docs/epics/e06/e06_skill_icon_batches.json"
record = json.load(sys.stdin)
source = Path(record["source"])
skill = record["id"]
queue = json.loads(QUEUE.read_text(encoding="utf-8-sig"))
match = [(batch, entry) for batch in queue["classes"] for entry in batch["entries"] if entry["id"] == skill]
assert len(match) == 1, "Unknown or duplicate skill"
batch, entry = match[0]
assert entry["status"] != "existing_painted", "Preserve previous art"
blob = source.read_bytes()
assert blob[:8] == b"\x89PNG\r\n\x1a\n"
width, height = struct.unpack(">II", blob[16:24])
assert width == height and width >= 128, "Expected square original source"
digest = hashlib.sha256(blob).hexdigest()
output = DEST / (skill + ".png")
assert not output.exists() or hashlib.sha256(output.read_bytes()).hexdigest() == digest, "Never overwrite different art"
shutil.copyfile(source, output)
manifest_path = DEST / "manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
assert not any(x["id"] == skill and x["sha256"] != digest for x in manifest["assets"])
if not any(x["id"] == skill for x in manifest["assets"]):
    manifest["assets"].append({"id": skill, "file": output.name, "class": batch["class"], "category": entry["category"], "tool": "built-in imagegen", "date": "2026-10-16", "source": str(source), "source_dimensions": [width, height], "sha256": digest, "prompt": record["prompt"]})
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
import_file = output.with_suffix(".png.import")
if not import_file.exists():
    template = (DEST / "shield_wall.png.import").read_text(encoding="utf-8-sig")
    template = "\n".join(line for line in template.splitlines() if not line.startswith("uid=")) + "\n"
    old_path = "res://assets/art/skills/painted/shield_wall.png"
    new_path = "res://assets/art/skills/painted/" + output.name
    old_hash = hashlib.md5(old_path.encode()).hexdigest()
    new_hash = hashlib.md5(new_path.encode()).hexdigest()
    template = template.replace(old_hash, new_hash).replace("shield_wall.png", output.name)
    import_file.write_text(template, encoding="utf-8")
entry.update(status="generated_pending_visual_validation", file=str(output.relative_to(ROOT)).replace("\\", "/"), sha256=digest)
batch["status"] = "in_progress"
queue["pending"] = sum(e["status"] == "pending" for b in queue["classes"] for e in b["entries"])
queue["generated_new"] = sum(e["status"] != "pending" and e["status"] != "existing_painted" for b in queue["classes"] for e in b["entries"])
QUEUE.write_text(json.dumps(queue, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"id": skill, "sha256": digest, "original_bytes_preserved": True, "remaining_to_generate": queue["pending"]}))
