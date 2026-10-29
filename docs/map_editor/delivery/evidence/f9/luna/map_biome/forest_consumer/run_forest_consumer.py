"""Prepare and run the pinned forest-map consumer probe after explicit release."""
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


root, fixture, engine = map(Path, sys.argv[1:4])
root = root.resolve()
fixture = fixture.resolve()
engine = engine.resolve()
evidence = Path(__file__).resolve().parent
script = evidence / "map_source_consumer_forest.gd.txt"
expected_fixture = root / ".godot/verification/e07_f1/fixture_project"
target = fixture / ".godot/f9_map_source_consumer_forest.gd"
expected_engine_sha256 = "ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_head() -> str:
    return subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()


def primary_inputs() -> list[dict]:
    rows = []
    for directory in ["scripts", "scenes", "resources", "content", "data", "assets", "addons/ragrpg_map_editor", "tests", "tools"]:
        for path in sorted((root / directory).rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(root).as_posix()
            if path.name.endswith(".import") and not rel.startswith("assets/art/map_authoring/props/"):
                continue
            mirror = fixture / rel
            rows.append({"path": rel, "sha256": digest(path), "fixture_sha256": digest(mirror) if mirror.is_file() else None})
    return rows


def explicit_imports() -> list[dict]:
    relative = [
        "assets/art/map_authoring/cliff_tile.png.import",
        "assets/art/map_authoring/earth_tile.png.import",
        "assets/art/map_authoring/grass_tile.png.import",
        "assets/art/map_authoring/sand_tile.png.import",
        "assets/art/map_authoring/props/broken_pillar.png.import",
        "assets/art/map_authoring/props/desert_cactus.png.import",
        "assets/art/map_authoring/props/moss_boulder.png.import",
        "assets/art/map_authoring/props/oak_tree.png.import",
        "assets/art/map_authoring/props/sandstone_boulder.png.import",
        "assets/art/map_authoring/props/woodland_shrub.png.import",
    ]
    return [
        {"path": rel, "source_sha256": digest(root / rel), "fixture_sha256": digest(fixture / rel) if (fixture / rel).is_file() else None}
        for rel in relative
    ]


def read_pending_pins() -> dict[str, str]:
    text = script.read_text(encoding="utf-8")
    names = ["EXPECTED_MAP_BYTES_SHA256", "EXPECTED_MAP_SOURCE_HASH", "EXPECTED_MAP_PACKAGE_HASH"]
    pins = {}
    for name in names:
        match = re.search(rf'const\s+{name}\s*:=\s*"([^"]+)"', text)
        if not match:
            raise RuntimeError(f"Missing pin declaration: {name}")
        pins[name] = match.group(1)
    if any(value == "PENDING_TERRA_RECEIPT" or not re.fullmatch(r"[0-9a-f]{64}", value) for value in pins.values()):
        raise RuntimeError("Terra source/package receipt pins are pending; refusing to start Godot.")
    return pins


if fixture != expected_fixture:
    raise SystemExit(f"Refusing noncanonical F1 fixture: {fixture}")
if not fixture.is_dir() or not engine.is_file():
    raise SystemExit("Expected fixture or Godot executable is missing.")
if digest(engine) != expected_engine_sha256:
    raise SystemExit("Godot executable SHA-256 does not match the reviewed F9 engine; no engine launched.")
pins = read_pending_pins()
before = primary_inputs()
head_before = git_head()
imports_before = explicit_imports()
source_path = root / "data/map_authoring/sanctuary_woods.map.json"
source_bytes_before = digest(source_path)
if any(row["sha256"] != row["fixture_sha256"] for row in before):
    raise SystemExit("Source/fixture primary input mismatch; no engine launched.")
if any(row["source_sha256"] != row["fixture_sha256"] for row in imports_before):
    raise SystemExit("Source/fixture import metadata mismatch; no engine launched.")
if source_bytes_before != pins["EXPECTED_MAP_BYTES_SHA256"]:
    raise SystemExit("Terra map bytes do not match the reviewed receipt pin; no engine launched.")

target.write_bytes(script.read_bytes())
profile = fixture / ".godot/discardable_profile"
env = os.environ.copy()
env.update(APPDATA=str(profile / "Roaming"), LOCALAPPDATA=str(profile / "Local"))
args = [
    str(engine), "--path", str(fixture), "--headless",
    "--log-file", str(evidence / "forest_consumer.engine.log"),
    "--script", "res://.godot/f9_map_source_consumer_forest.gd",
]
started = time.time()
timed_out = False
try:
    proc = subprocess.run(args, cwd=fixture, env=env, capture_output=True, timeout=300)
    code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
except subprocess.TimeoutExpired as exc:
    code = None
    stdout = exc.stdout if isinstance(exc.stdout, bytes) else (exc.stdout or "").encode()
    stderr = exc.stderr if isinstance(exc.stderr, bytes) else (exc.stderr or "").encode()
    timed_out = True

(evidence / "forest_consumer.stdout.log").write_bytes(stdout)
(evidence / "forest_consumer.stderr.log").write_bytes(stderr)
stdout_text = stdout.decode("utf-8", errors="replace")
marker = "F9_MAP_SOURCE_CONSUMER_RESULT "
lines = [line[len(marker):] for line in stdout_text.splitlines() if line.startswith(marker)]
result = json.loads(lines[0]) if len(lines) == 1 else None
engine_log_path = evidence / "forest_consumer.engine.log"
engine_log = engine_log_path.read_text(encoding="utf-8", errors="replace") if engine_log_path.exists() else ""
error_pattern = re.compile(r"SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)")
generic_errors = bool(error_pattern.search(stdout_text + "\n" + stderr.decode("utf-8", errors="replace") + "\n" + engine_log))
after = primary_inputs()
imports_after = explicit_imports()
head_after = git_head()
source_bytes_after = digest(source_path)
inputs_unchanged = before == after and imports_before == imports_after and head_before == head_after and source_bytes_before == source_bytes_after
manifest = {
    "head_before": head_before,
    "head_after": head_after,
    "engine": str(engine),
    "engine_sha256": digest(engine),
    "expected_engine_sha256": expected_engine_sha256,
    "fixture": str(fixture),
    "arguments": args[1:],
    "working_directory": str(fixture),
    "environment": {"APPDATA": env["APPDATA"], "LOCALAPPDATA": env["LOCALAPPDATA"]},
    "script_sha256": digest(script),
    "pins": pins,
    "inputs": before,
    "primary_input_count": len(before),
    "terrain_imports": imports_before,
    "terrain_import_count": len(imports_before),
    "map_source_bytes_sha256_before": source_bytes_before,
    "map_source_bytes_sha256_after": source_bytes_after,
    "inputs_unchanged": inputs_unchanged,
    "exit_code": code,
    "timed_out": timed_out,
    "elapsed_seconds": round(time.time() - started, 3),
    "generic_errors": generic_errors,
    "result": result,
}
manifest["ok"] = (
    code == 0 and not timed_out and not generic_errors and inputs_unchanged
    and len(imports_before) == 10 and result is not None
    and result.get("ok") is True and result.get("count") == 12
)
(evidence / "forest_consumer.manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps({key: value for key, value in manifest.items() if key != "inputs"}, ensure_ascii=False))
sys.exit(0 if manifest["ok"] else 1)
