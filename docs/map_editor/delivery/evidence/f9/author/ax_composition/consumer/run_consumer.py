"""Directed decorated-source consumer proof; no product composition is persisted."""
import hashlib, json, os, re, subprocess, sys, time
from pathlib import Path
root, fixture, engine = map(Path, sys.argv[1:4])
evidence = Path(__file__).resolve().parent
script = evidence / 'map_source_consumer.gd.txt'
target = fixture / '.godot/f9_map_source_consumer.gd'
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def git_head():
    return subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'], text=True).strip()
def primary_inputs():
    rows = []
    for directory in ['scripts','scenes','resources','content','data','assets','addons/ragrpg_map_editor','tests','tools']:
        for path in sorted((root / directory).rglob('*')):
            if path.is_file() and (not path.name.endswith('.import') or path.relative_to(root).as_posix().startswith('assets/art/map_authoring/props/')):
                rel = path.relative_to(root).as_posix()
                mirror = fixture / rel
                rows.append({'path':rel, 'sha256':digest(path), 'fixture_sha256':digest(mirror) if mirror.exists() else None})
    return rows
before = primary_inputs()
head = git_head()
metadata = [root / 'assets/art/map_authoring' / (name + '.png.import') for name in ['grass_tile','earth_tile','sand_tile','cliff_tile']]
imports = [{'path':p.relative_to(root).as_posix(),'source':digest(p),'fixture':digest(fixture/p.relative_to(root))} for p in metadata]
# Explicit terrain dependencies from the normalization receipt.
assert all(row['sha256'] == row['fixture_sha256'] for row in before), 'source/fixture mismatch'
assert all(row['source'] == row['fixture'] for row in imports), 'terrain import mismatch'
target.write_bytes(script.read_bytes())
profile = fixture / '.godot/discardable_profile'
env = os.environ.copy()
env.update(APPDATA=str(profile/'Roaming'), LOCALAPPDATA=str(profile/'Local'))
args = [str(engine),'--path',str(fixture),'--headless','--log-file',str(evidence/'consumer.engine.log'),'--script','res://.godot/f9_map_source_consumer.gd']
started = time.time()
timed_out = False
try:
    proc = subprocess.run(args, cwd=fixture, env=env, capture_output=True, timeout=300)
    code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
except subprocess.TimeoutExpired as exc:
    code, stdout, stderr, timed_out = None, exc.stdout or b'', exc.stderr or b'', True
(evidence/'consumer.stdout.log').write_bytes(stdout)
(evidence/'consumer.stderr.log').write_bytes(stderr)
text = stdout.decode('utf-8',errors='replace')
marker = 'F9_MAP_SOURCE_CONSUMER_RESULT '
lines = [line[len(marker):] for line in text.splitlines() if line.startswith(marker)]
result = json.loads(lines[0]) if len(lines) == 1 else None
engine_log = (evidence/'consumer.engine.log').read_text(encoding='utf-8',errors='replace') if (evidence/'consumer.engine.log').exists() else ''
errors = bool(re.search(r'SCRIPT ERROR|Parse Error|(?m:^ERROR:)', text+'\n'+stderr.decode('utf-8',errors='replace')+'\n'+engine_log))
after = primary_inputs()
head_after = git_head()
unchanged = before == after and head == head_after
manifest = {'head_before':head,'head_after':head_after,'engine':str(engine),'engine_sha256':digest(engine),'fixture':str(fixture),'arguments':args[1:],'working_directory':str(fixture),'environment':{'APPDATA':env['APPDATA'],'LOCALAPPDATA':env['LOCALAPPDATA']},'script_sha256':digest(script),'inputs':before,'terrain_imports':imports,'primary_count':len(before),'inputs_unchanged':unchanged,'exit_code':code,'timed_out':timed_out,'elapsed_seconds':round(time.time()-started,3),'generic_errors':errors,'result':result}
manifest['ok'] = code == 0 and not timed_out and not errors and unchanged and result is not None and result.get('ok') is True and result.get('count') == 10
(evidence/'consumer.manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v for k,v in manifest.items() if k not in ['inputs','terrain_imports']},ensure_ascii=False))
sys.exit(0 if manifest['ok'] else 1)
