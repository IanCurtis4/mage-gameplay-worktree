"""Instrument an exact compiler copy; never alter the product or AX draft."""
import hashlib, json, os, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[7]
FIXTURE = ROOT / '.godot/verification/e07_f1/fixture_project'
ENGINE = ROOT.parent / 'godot/Godot_v4.7.2-stable_win64.exe'
OUT = Path(__file__).parent / 'population_diagnostic_02'
OUT.mkdir(exist_ok=False)
scratch = FIXTURE / '.godot/population_diagnostic_02'
scratch.mkdir(exist_ok=False)
source = ROOT / 'docs/map_editor/delivery/evidence/f9/terra/area_encounters/population_draft_01.json'
compiler = FIXTURE / 'scripts/map_authoring/population/population_compiler.gd'
raw = compiler.read_text(encoding='utf-8-sig')
assert hashlib.sha256(compiler.read_bytes()).digest() == hashlib.sha256((ROOT / compiler.relative_to(FIXTURE)).read_bytes()).digest()
old = '\treturn world.position_query(destination,profile,world.geometry_revision).ok and world.path(entry,destination,profile,world.geometry_revision).ok and world.path(destination,entry,profile,world.geometry_revision).ok'
new = '''\tprint("TRACE path begin ",Time.get_ticks_msec()," ",entry.to_data()," -> ",destination.to_data())
\tif not world.position_query(destination,profile,world.geometry_revision).ok: return false
\tvar trace := {"enabled":true}
\tvar outward := world._path(entry,destination,profile,world.geometry_revision,null,true,trace)
\tprint("TRACE path outward ",Time.get_ticks_msec()," ok=",outward.ok," ",trace)
\tif not outward.ok: return false
\ttrace = {"enabled":true}
\tvar inward := world._path(destination,entry,profile,world.geometry_revision,null,true,trace)
\tprint("TRACE path inward ",Time.get_ticks_msec()," ok=",inward.ok," ",trace)
\treturn inward.ok'''
assert raw.count(old) == 1
raw = raw.replace(old,new)
raw = raw.replace('\tvar built := MapCompiler.compile(', '\tprint("TRACE map begin ",Time.get_ticks_msec())\n\tvar built := MapCompiler.compile(',1)
raw = raw.replace('\tif not built.ok: return built','\tprint("TRACE map end ",Time.get_ticks_msec()," ok=",built.ok)\n\tif not built.ok: return built',1)
raw = raw.replace('\tvar context := prepare(source,cancel)','\tprint("TRACE prepare begin ",Time.get_ticks_msec())\n\tvar context := prepare(source,cancel)\n\tprint("TRACE prepare end ",Time.get_ticks_msec()," ok=",context.ok)')
(scratch / 'population_trace.gd').write_text(raw,encoding='utf-8')
(scratch / 'probe.gd').write_text('''extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
\tvar loaded: Dictionary = load("res://scripts/map_authoring/population/population_store.gd").load_source(%s)
\tif not loaded.ok:
\t\tprint("TRACE source invalid ",loaded)
\t\tquit(2)
\t\treturn
\tvar source: Dictionary = loaded.data
\tvar result: Dictionary = load("res://.godot/population_diagnostic_02/population_trace.gd").regenerate(source)
\tprint("TRACE result ",result.get("ok")," ",result.get("code",""))
\tquit(0 if result.get("ok",false) else 1)
''' % json.dumps(str(source)),encoding='utf-8')
env = os.environ.copy()
profile = FIXTURE / '.godot/discardable_profile'
env.update(APPDATA=str(profile/'Roaming'),LOCALAPPDATA=str(profile/'Local'))
head = subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
argv = [str(ENGINE),'--headless','--path',str(FIXTURE),'--log-file',str(OUT/'engine.log'),'--script','res://.godot/population_diagnostic_02/probe.gd']
start = time.monotonic()
timed_out = False
try:
    p = subprocess.run(argv,cwd=FIXTURE,env=env,capture_output=True,timeout=120)
    code,stdout,stderr = p.returncode,p.stdout,p.stderr
except subprocess.TimeoutExpired as e:
    code,stdout,stderr,timed_out = None,e.stdout or b'',e.stderr or b'',True
(OUT/'stdout.log').write_bytes(stdout)
(OUT/'stderr.log').write_bytes(stderr)
record = {'head':head,'head_after':subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip(),'fixture':str(FIXTURE),'engine_sha256':hashlib.sha256(ENGINE.read_bytes()).hexdigest(),'compiler_sha256':hashlib.sha256(compiler.read_bytes()).hexdigest(),'draft_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'elapsed_seconds':time.monotonic()-start,'exit_code':code,'timed_out':timed_out,'arguments':argv,'instrumentation_only':True,'diagnostic_guard_seconds':120}
(OUT/'receipt.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps(record))
print(stdout.decode('utf-8',errors='replace')[-12000:])
print(stderr.decode('utf-8',errors='replace')[-3000:])
