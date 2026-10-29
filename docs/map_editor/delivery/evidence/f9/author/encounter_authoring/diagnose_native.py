"""Run an instrumented copy with every original native oracle unchanged."""
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[7]
HERE = Path(__file__).resolve().parent / 'native_diagnostic_01'
FIXTURE = ROOT / '.godot/verification/e07_f1/fixture_project'
ENGINE = ROOT.parent / 'godot/Godot_v4.7.2-stable_win64.exe'
HERE.mkdir()
source_path = ROOT / 'tests/map_editor_encounter_authoring_ui_test.gd'
source = source_path.read_bytes()
text = source.decode('utf-8')
needle = '\tcheck("real_patrol_controls_mode_wait_move_and_slot_assignment_match_ax",'
assert text.count(needle) == 1
diagnostic = '\tprint("F9_ENCOUNTER_DIAGNOSTIC "+JSON.stringify({"before_mode_loop":gui_route_data.mode == "loop","mode_call_ok":ax_mode_route_result.ok,"wait_call_ok":ax_wait.ok,"move_call_ok":ax_move.ok,"assign_call_ok":ax_assign.ok,"before_route_gui":route_before_move == gui_route_before_move,"before_route_ax":route_before_move == ax_route_before_move,"same_route":gui_patrol.session.data.patrols[0] == ax_patrol.session.data.patrols[0],"mode_is_ping_pong":gui_patrol.session.data.patrols[0].mode == "ping_pong","point_id_match":gui_patrol.session.data.patrols[0].waypoints[2].point_id == wait_point_id,"actual_wait":gui_patrol.session.data.patrols[0].waypoints[2].wait_seconds,"expected_wait":1.75,"control_step":gui_patrol.wait_time.step,"slots_ok":gui_patrol.session.data.patrols[0].slot_ids == ["guard"],"document_valid":PatrolDocument.validate(gui_patrol.session.data).ok}))\n'
instrumented = text.replace(needle, diagnostic + needle).encode('utf-8')
(HERE / 'native_instrumented.gd.txt').write_bytes(instrumented)
target = FIXTURE / '.godot/f9_encounter_native_diagnostic.gd'
target.write_bytes(instrumented)
env = os.environ.copy()
profile = FIXTURE / '.godot/discardable_profile'
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), F9_EVIDENCE=str(HERE))
head = subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
assert head == '5a97f7d7e095b36d65795140bae82a7178b73d6b'
args = [str(ENGINE),'--path',str(FIXTURE),'--rendering-method','gl_compatibility','--log-file',str(HERE/'native.engine.log'),'--script','res://.godot/f9_encounter_native_diagnostic.gd']
process = subprocess.run(args,cwd=FIXTURE,env=env,capture_output=True,timeout=300)
(HERE/'native.stdout.log').write_bytes(process.stdout)
(HERE/'native.stderr.log').write_bytes(process.stderr)
stdout = process.stdout.decode('utf-8',errors='replace')
lines = [line.removeprefix('F9_ENCOUNTER_DIAGNOSTIC ') for line in stdout.splitlines() if line.startswith('F9_ENCOUNTER_DIAGNOSTIC ')]
detail = json.loads(lines[0]) if len(lines) == 1 else None
errors = bool(re.search(r'SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)',stdout+process.stderr.decode('utf-8',errors='replace')+(HERE/'native.engine.log').read_text(encoding='utf-8',errors='replace')))
unchanged = source == source_path.read_bytes() and head == subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
result = {'scope':'diagnostic copy; same original 25 oracles, only one JSON print inserted; no expectation or production changes','head':head,'arguments':args,'environment':{'APPDATA':env['APPDATA'],'LOCALAPPDATA':env['LOCALAPPDATA'],'F9_EVIDENCE':env['F9_EVIDENCE']},'original_test_sha256':hashlib.sha256(source).hexdigest(),'instrumented_sha256':hashlib.sha256(instrumented).hexdigest(),'exit_code':process.returncode,'generic_errors':errors,'source_and_head_unchanged':unchanged,'diagnostic':detail}
(HERE/'diagnostic.manifest.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
assert process.returncode == 1 and not errors and unchanged and detail is not None
