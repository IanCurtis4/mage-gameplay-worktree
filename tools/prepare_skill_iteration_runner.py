"""Copy the exact candidate files into a disposable Godot verification workspace."""
from pathlib import Path
import subprocess, shutil, hashlib, json
source = Path(__file__).resolve().parents[1]
runner = source / ".godot/verification/skill_iteration_runner"
runner.mkdir(parents=True, exist_ok=True)
raw = subprocess.check_output(["git", "-c", "safe.directory="+str(source), "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=source)
records = []
for name in raw.decode("utf-8").split("\0"):
    if not name or name.startswith((".godot/", ".tools/", ".git/", "addons/")): continue
    path = source/name
    if not path.is_file(): continue
    target = runner/name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
    if name == "project.godot":
        configuration = target.read_text(encoding="utf-8-sig")
        configuration = configuration.replace('version_control/autoload_on_startup=true', 'version_control/autoload_on_startup=false')
        target.write_text(configuration, encoding="utf-8")
    records.append({"path":name, "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
(source / ".godot/verification/skill_iteration_runner_inputs.json").write_text(json.dumps({"files":records, "runner":str(runner), "ignored_cache_and_addons_excluded":True, "runner_editor_vcs_autoload_disabled":True}, indent=2), encoding="utf-8")
print(str(runner))
