"""Consolidate actual frozen validation receipts and current input bytes."""
import hashlib, json, subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
LUNA=ROOT/'docs/map_editor/delivery/evidence/f9/luna/encounter_authoring'
FIXTURE=ROOT/'.godot/verification/e07_f1/fixture_project'
HEAD='3a5bff35a573cce3ac76439d68d59eaed87c7974'
ENGINE_SHA='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def check_inputs(rows):
    for row in rows:
        actual=sha(ROOT/row['path'])
        assert actual==row['sha256'].lower()==sha(FIXTURE/row['path']),row['path']
    return len(rows)
assert subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()==HEAD
receipts=[]
completion_paths=set()
for name, count in [('model_02',27),('native_02',25),('gameplay_native',52)]:
    path=LUNA/name/'runs.json'; data=read(path)
    assert data['ok'] and data['exit_code']==0 and not data['timed_out'] and not data['aborted']
    assert data['head_before']==data['head_after']==HEAD and data['engine_sha256'].lower()==ENGINE_SHA
    assert Path(data['fixture']).resolve()==FIXTURE.resolve()
    assert data['result']['ok'] and data['result']['count']==count and len(data['result']['checks'])==count and all(r['ok'] for r in data['result']['checks'])
    assert check_inputs(data['inputs'])==2054
    completion_paths={r['path'] for r in data['inputs']}
    receipts.append({'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),'checks':count,'inputs':2054,'mismatches':0})
path=LUNA/'context_01/manifest.json'; data=read(path)
assert data['head_before']==data['head_after']==HEAD and data['engine_sha256'].lower()==ENGINE_SHA
assert Path(data['fixture']).resolve()==FIXTURE.resolve() and check_inputs(data['inputs'])==2048
assert [(r['name'],r['result']['count'] if r.get('result') else None) for r in data['runs']]==[('import',None),('candidate',53),('population',91),('patrol',58),('exchange',113)]
assert all(r['ok'] and r['exit_code']==0 and not r['aborted'] and not r['timed_out'] for r in data['runs'])
excluded=sorted(completion_paths-{r['path'] for r in data['inputs']})
assert len(excluded)==6 and all(p.startswith('assets/art/map_authoring/props/') and p.endswith('.import') for p in excluded)
receipts.append({'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),'checks':315,'inputs':2048,'mismatches':0})
plan=read(LUNA/'verify/plan.json')
checks=[json.loads(line) for line in (LUNA/'verify/checks.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
executed=[r for r in checks if r.get('name')=='editor_import']
assert plan['source_commit']==HEAD and plan['selected_steps']==1 and plan['total_steps']==299
assert len(executed)==1 and not executed[0]['failed'] and executed[0]['exit_code']==0 and not executed[0]['timed_out']
imports=[]
for path in sorted((ROOT/'assets/art/map_authoring').rglob('*.png.import')):
    relative=path.relative_to(ROOT)
    if relative.as_posix().startswith('assets/art/map_authoring/props/') or path.stem in ['grass_tile.png','earth_tile.png','sand_tile.png','cliff_tile.png']:
        assert sha(path)==sha(FIXTURE/relative)
        imports.append({'path':relative.as_posix(),'sha256':sha(path)})
assert len(imports)==10
cli_path=HERE/'cli_01/manifest.json'
cli=read(cli_path)
assert cli['ok'] and cli['head_before']==cli['head_after']==HEAD and cli['engine_sha256']==ENGINE_SHA and cli['inputs_unchanged']
assert check_inputs(cli['inputs'])==2054 and cli['equivalence']['headless']==cli['equivalence']['native']
assert [(r['name'],r['completed'],r['requested'],r['exit_code']) for r in cli['runs']]==[('preview',2,2,0),('headless',12,12,0),('native',12,12,0),('reopen',4,4,0),('rejected',2,3,1)]
assert all(r['ok'] and not r['generic_errors'] for r in cli['runs'])
for name in ['headless','native']:
    assert sha(HERE/'cli_01'/(name+'.population.json'))==cli['equivalence'][name]['population_bytes']
    assert sha(HERE/'cli_01'/(name+'.patrol.json'))==cli['equivalence'][name]['patrol_bytes']
result={'ok':True,'scope':'Luna execution and Sol consolidation; not independent semantic audit; native01 failure and instrumented diagnostic preserved separately, not counted as PASS','head':HEAD,'engine_sha256':ENGINE_SHA,'receipts':receipts,'completion_only_imports':excluded,'dependency_imports':imports,'verify':{'selected_steps':1,'catalog_steps':299,'test':'editor_import','ok':True},'limits':'CLI transport still separate; no Bosque population/patrol product sources, App/gameplay/FPS for new content, F9 overall remains open'}
result['cli']={'path':cli_path.relative_to(ROOT).as_posix(),'sha256':sha(cli_path),'ok':True,'inputs':2054,'processes':5,'equivalence':cli['equivalence']}
result['limits']='Producer and real CLI validated on disposable fixtures; no Bosque population/patrol product sources or new App/gameplay/FPS proof; full F9 remains open'
(HERE/'validation_audit.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'ok':True,'receipts':len(receipts),'imports':10,'mismatches':0}))
