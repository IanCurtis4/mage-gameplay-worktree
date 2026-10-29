"""Measure the whole unchanged AX draft with an instrumented compiler copy."""
import argparse, hashlib, json, os, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[7]
FIXTURE = ROOT / '.godot/verification/e07_f1/fixture_project'
ENGINE = ROOT.parent / 'godot/Godot_v4.7.2-stable_win64.exe'
parser = argparse.ArgumentParser()
parser.add_argument('--attempt', required=True)
args = parser.parse_args()
assert args.attempt.isalnum()
name = 'population_measure_' + args.attempt
out = Path(__file__).parent / name
out.mkdir(exist_ok=False)
scratch = FIXTURE / '.godot' / name
scratch.mkdir(exist_ok=False)
source = ROOT / 'docs/map_editor/delivery/evidence/f9/terra/area_encounters/population_draft_01.json'
compiler = FIXTURE / 'scripts/map_authoring/population/population_compiler.gd'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(compiler) == sha(ROOT / compiler.relative_to(FIXTURE))
raw = compiler.read_text(encoding='utf-8-sig')
raw = raw.replace('\tvar checked := world.connectivity_batch(', '\tprint("MEASURE batch begin ",Time.get_ticks_msec()," targets=",targets.size())\n\tvar checked := world.connectivity_batch(',1)
raw = raw.replace('\tif not checked.ok:\n\t\tvar failure := fail(str(checked.error_code))', '\tprint("MEASURE batch end ",Time.get_ticks_msec()," ok=",checked.ok," ",checked.data.get("metrics",{}))\n\tif not checked.ok:\n\t\tvar failure := fail(str(checked.error_code))',1)
raw = raw.replace('\tvar built := MapCompiler.compile(', '\tprint("MEASURE map begin ",Time.get_ticks_msec())\n\tvar built := MapCompiler.compile(',1)
raw = raw.replace('\tif not built.ok: return built', '\tprint("MEASURE map end ",Time.get_ticks_msec()," ok=",built.ok)\n\tif not built.ok: return built',1)
(scratch/'population_trace.gd').write_text(raw,encoding='utf-8')
probe = '''extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
\tvar loaded: Dictionary = load("res://scripts/map_authoring/population/population_store.gd").load_source(SOURCE)
\tif not loaded.ok:
\t\tprint("MEASURE invalid source ",loaded)
\t\tquit(2)
\t\treturn
\tvar frozen: Dictionary = loaded.data.duplicate(true)
\tvar result: Dictionary = load(COMPILER).regenerate(loaded.data)
\tvar record := {"ok":result.ok,"code":result.get("code",""),"no_mutation":loaded.data == frozen,"slots":result.get("data",{}).get("slots",[]).size(),"metrics":result.get("metrics",[]),"diagnostics":result.get("diagnostics",[]),"geometry_diagnostic":result.get("geometry_diagnostic",{})}
\tprint("MEASURE result ",JSON.stringify(record))
\tvar file := FileAccess.open(RESULT,FileAccess.WRITE)
\tfile.store_string(JSON.stringify(record,"\\t",true,true)); file.close()
\tquit(0 if result.ok else 1)
'''.replace('SOURCE',json.dumps(str(source))).replace('COMPILER',json.dumps('res://.godot/'+name+'/population_trace.gd')).replace('RESULT',json.dumps(str(out/'result.json')))
(scratch/'probe.gd').write_text(probe,encoding='utf-8')
for filename in ['probe.gd','population_trace.gd']:
    (out/(filename+'.txt')).write_bytes((scratch/filename).read_bytes())
env = os.environ.copy(); profile = FIXTURE/'.godot/discardable_profile'
env.update(APPDATA=str(profile/'Roaming'),LOCALAPPDATA=str(profile/'Local'))
head = subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
argv = [str(ENGINE),'--headless','--path',str(FIXTURE),'--log-file',str(out/'engine.log'),'--script','res://.godot/'+name+'/probe.gd']
start=time.monotonic(); timed_out=False
try:
    p=subprocess.run(argv,cwd=FIXTURE,env=env,capture_output=True,timeout=300)
    code,stdout,stderr=p.returncode,p.stdout,p.stderr
except subprocess.TimeoutExpired as e:
    code,stdout,stderr,timed_out=None,e.stdout or b'',e.stderr or b'',True
(out/'stdout.log').write_bytes(stdout); (out/'stderr.log').write_bytes(stderr)
record={'head':head,'head_after':subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip(),'engine_sha256':sha(ENGINE),'compiler_sha256':sha(compiler),'draft_sha256':sha(source),'elapsed_seconds':time.monotonic()-start,'exit_code':code,'timed_out':timed_out,'arguments':argv,'instrumentation_only':True}
(out/'receipt.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps(record)); print(stdout.decode('utf-8',errors='replace')[-14000:]); print(stderr.decode('utf-8',errors='replace')[-4000:])
